//! Reference external nonce seeker for `proxi node mine`
//! (kb/external_nonce_seeker.md in the Proxima repository).
//!
//! It polls the miner for the current job, searches nonces on every core and
//! posts improving solutions until the same job expires. Modified locally to add --gpu CUDA
//! searches, with a CPU reference check of every accelerator hit.
//! It holds the wallet key, because the
//! VRF output needs the secret scalar, and nothing else: the miner verifies
//! the nonce, completes the proof, builds and submits the transaction.

#[path="../client.rs"] mod client;
#[path="../key.rs"] mod key;
#[path="../gpu_cuda.rs"] mod gpu;
#[path="../identity_pool.rs"] mod identities;
#[path="../job_protocol.rs"] mod job_protocol;

use client::{Client, Verdict};
use identities::{IdentityPool, MiningIdentity};
use rand::Rng;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex, RwLock};
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const SEED_ENV: &str = "NONCE_SEEKER_SEED";
/// how long one job poll is held open on the miner's side
const POLL_WAIT_MS: u64 = 5000;
/// attempts between two looks at the shared job
const BATCH: u64 = 256;
const REPORT_EVERY: Duration = Duration::from_secs(1);
const RATE_LINE_EVERY: Duration = Duration::from_secs(10);
const RETRY_MIN: Duration = Duration::from_secs(1);
const RETRY_MAX: Duration = Duration::from_secs(30);

struct Config {
    proxi: String,
    token: Option<String>,
    key_file: PathBuf,
    identities: Option<PathBuf>,
    threads: usize,
    name: String,
    gpu: bool,
    gpu_batch: usize,
    gpu_streams: usize,
}

/// One search target, as the workers see it. Immutable once installed; a new
/// job is a new value; only its host-side beat and bounded lease may tighten.
struct Job {
    identity: Arc<MiningIdentity>,
    id: u64,
    slot: u64,
    alpha_prefix: Vec<u8>,
    k: u32,
    control: job_protocol::JobControl,
}

struct Shared {
    job: RwLock<Option<Arc<Job>>>,
    /// An inconsistent opaque ID stays refused until an explicit no-job or ID change.
    refused_id: AtomicU64,
    /// attempts made and not yet reported to the miner
    attempts: AtomicU64,
    /// One lock keeps aggregate and per-identity snapshots consistent. Result
    /// submissions must not reset these independent GPU telemetry counters.
    gpu_telemetry: Mutex<GpuTelemetry>,
    session_started_at_ms: u64,
}

#[derive(Clone, Copy, Default)]
struct GpuCounters {
    attempts: u64,
    active_ns: u64,
    drain_attempts: u64,
}

#[derive(Clone)]
struct GpuTelemetry {
    totals: GpuCounters,
    identities: Vec<GpuCounters>,
    difficulties: Vec<GpuCounters>,
}

struct GpuTelemetryWindow {
    attempts: u64,
    total_attempts: u64,
    active_s: f64,
    total_active_s: f64,
    identities: Vec<serde_json::Value>,
    difficulties: Vec<serde_json::Value>,
    drain_attempts:u64,
    total_drain_attempts:u64,
}

impl GpuTelemetry {
    fn new(identity_count: usize) -> Self {
        Self {
            totals: GpuCounters::default(),
            identities: vec![GpuCounters::default(); identity_count],
            difficulties: vec![GpuCounters::default(); 513],
        }
    }

    fn record_job(&mut self,index:usize,k:u32,attempts:u64,active_ns:u64,drained:bool){
        assert!(k<=512);self.record(index,attempts,active_ns);
        let difficulty=&mut self.difficulties[k as usize];difficulty.attempts+=attempts;difficulty.active_ns+=active_ns;
        if drained{difficulty.drain_attempts+=attempts;self.identities[index].drain_attempts+=attempts;self.totals.drain_attempts+=attempts;}
    }

    fn record(&mut self, index: usize, attempts: u64, active_ns: u64) {
        // The immutable job owns the validated manifest index. A simultaneous
        // job replacement cannot attribute this completed call to its successor.
        let identity = &mut self.identities[index];
        identity.attempts += attempts;
        identity.active_ns += active_ns;
        self.totals.attempts += attempts;
        self.totals.active_ns += active_ns;
    }

    fn window(&self, previous: &Self) -> GpuTelemetryWindow {
        let mut active_s = 0.0;
        let mut total_active_s = 0.0;
        let identities = self.identities.iter().zip(&previous.identities).enumerate().map(|(index, (current, old))| {
            let delta_s = (current.active_ns - old.active_ns) as f64 / 1e9;
            let total_s = current.active_ns as f64 / 1e9;
            // Sum the same floating-point values emitted in the identity rows.
            active_s += delta_s;
            total_active_s += total_s;
            serde_json::json!({
                "index": index,
                "attempts": current.attempts - old.attempts,
                "active_s": delta_s,
                "total_attempts": current.attempts,
                "total_active_s": total_s,
                "drain_attempts":current.drain_attempts-old.drain_attempts,
                "total_drain_attempts":current.drain_attempts,
            })
        }).collect();
        GpuTelemetryWindow {
            attempts: self.totals.attempts - previous.totals.attempts,
            total_attempts: self.totals.attempts,
            active_s,
            total_active_s,
            identities,
            difficulties:self.difficulties.iter().zip(&previous.difficulties).enumerate().filter(|(_, (value,_))|value.attempts>0).map(|(k,(value,old))|serde_json::json!({
                "k":k,"attempts":value.attempts-old.attempts,"total_attempts":value.attempts,
                "active_s":(value.active_ns-old.active_ns)as f64/1e9,"total_active_s":value.active_ns as f64/1e9,
                "drain_attempts":value.drain_attempts-old.drain_attempts,"total_drain_attempts":value.drain_attempts,
            })).collect(),
            drain_attempts:self.totals.drain_attempts-previous.totals.drain_attempts,
            total_drain_attempts:self.totals.drain_attempts,
        }
    }
}

fn main() {
    let session_started_at_ms = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_millis() as u64;
    let cfg = match parse_args() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("{e}");
            eprintln!("usage: nonce_seeker --proxi URL [--token T] [--key-file FILE | --identities MANIFEST] [--threads N] [--name NAME] [--gpu] [--gpu-batch N] [--gpu-streams N]");
            std::process::exit(2);
        }
    };
    let pool = match cfg.identities.as_ref().map_or_else(||load_seed(&cfg).map(IdentityPool::single), |path|IdentityPool::load(path)) {
        Ok(p) => Arc::new(p),
        Err(e) => {
            eprintln!("cannot load the key: {e}");
            std::process::exit(1);
        }
    };
    let client = Arc::new(Client::new(&cfg.proxi, cfg.token.clone()));
    let shared = Arc::new(Shared {
        job: RwLock::new(None), refused_id: AtomicU64::new(0), attempts: AtomicU64::new(0),
        gpu_telemetry: Mutex::new(GpuTelemetry::new(pool.len())),
        session_started_at_ms,
    });

    log(&format!(
        "nonce seeker '{}': {} local mining identities, {} threads, miner at {}",
        cfg.name,
        pool.len(),
        cfg.threads,
        cfg.proxi
    ));

    for tid in 0..cfg.threads {
        let (shared, client, name) = (shared.clone(), client.clone(), cfg.name.clone());
        let threads = cfg.threads;
        thread::spawn(move || worker(tid, threads, &shared, &client, &name));
    }
    if cfg.gpu {
        let (shared, client, name) = (shared.clone(), client.clone(), cfg.name.clone());
        let initial = pool.first();
        let batch=cfg.gpu_batch;
        let streams=cfg.gpu_streams;
        thread::spawn(move || {
            if let Err(e)=gpu_worker(&initial.seed,batch,streams,&shared,&client,&name){
                log(&format!("GPU FATAL: {e}"));std::process::exit(1);
            }
        });
    }
    {
        let (shared, client, name) = (shared.clone(), client.clone(), cfg.name.clone());
        thread::spawn(move || reporter(&shared, &client, &name));
    }
    poller(&shared, &client, &pool);
}

fn parse_args() -> Result<Config, String> {
    parse_args_from(std::env::args().skip(1))
}

fn parse_args_from(mut args:impl Iterator<Item=String>) -> Result<Config, String> {
    let mut cfg = Config {
        proxi: String::new(),
        token: None,
        key_file: PathBuf::from("proxima.key"),
        identities: None,
        threads: thread::available_parallelism().map(|n| n.get()).unwrap_or(1),
        name: format!("seeker-{}", std::process::id()),
        gpu: false,
        gpu_batch: 131072,
        gpu_streams: 6,
    };
    let mut explicit_threads=false;
    while let Some(a) = args.next() {
        let mut value = |flag: &str| args.next().ok_or(format!("{flag} needs a value"));
        match a.as_str() {
            "--proxi" => cfg.proxi = value("--proxi")?,
            "--token" => cfg.token = Some(value("--token")?),
            "--key-file" => cfg.key_file = PathBuf::from(value("--key-file")?),
            "--identities" | "--identity-manifest" => cfg.identities = Some(PathBuf::from(value("--identities")?)),
            "--threads" => {
                explicit_threads=true;
                cfg.threads = value("--threads")?.parse().map_err(|e| format!("--threads: {e}"))?;
            }
            "--gpu" => cfg.gpu=true,
            "--gpu-batch" => cfg.gpu_batch=value("--gpu-batch")?.parse().map_err(|e|format!("--gpu-batch: {e}"))?,
            "--gpu-streams" => cfg.gpu_streams=value("--gpu-streams")?.parse().map_err(|e|format!("--gpu-streams: {e}"))?,
            "--name" => cfg.name = value("--name")?,
            other => return Err(format!("unknown argument {other}")),
        }
    }
    if cfg.gpu && !explicit_threads {cfg.threads=0;}
    if cfg.threads==0 && !cfg.gpu {return Err("--threads must be at least 1 without --gpu".into())}
    if !(1024..=131072).contains(&cfg.gpu_batch){return Err("--gpu-batch must be 1024..131072".into())}
    if !(1..=8).contains(&cfg.gpu_streams){return Err("--gpu-streams must be 1..8".into())}
    if cfg.proxi.is_empty() {
        return Err("--proxi URL is required (the address 'proxi node mine' serves jobs on)".into());
    }
    Ok(cfg)
}

/// The key file wins over the environment seed when both are present.
fn load_seed(cfg: &Config) -> Result<[u8; 32], String> {
    if cfg.key_file.exists() {
        return key::load_seed(&cfg.key_file);
    }
    if let Ok(s) = std::env::var(SEED_ENV) {
        return key::seed_from_hex(&s);
    }
    Err(format!("no key file at {} and {SEED_ENV} is not set", cfg.key_file.display()))
}

/// Keeps the shared job current. Errors are retried forever with backoff: a
/// miner restarts, a network blips, and the seeker must simply be there when
/// the jobs come back.
fn poller(shared: &Shared, client: &Client, pool: &IdentityPool) {
    let mut after = 0u64;
    let mut retry = RETRY_MIN;
    loop {
        let wire = match client.get_job(after, POLL_WAIT_MS) {
            Ok(w) => {
                retry = RETRY_MIN;
                w
            }
            Err(e) => {
                log(&format!("cannot reach the miner: {e}; retrying in {retry:?}"));
                thread::sleep(retry);
                retry = (retry * 2).min(RETRY_MAX);
                continue;
            }
        };
        after = wire.id;
        match apply_job(shared, pool, &wire) {
            Ok(true) if wire.id != 0 => {
                let current=shared.job.read().unwrap();let job=current.as_ref().unwrap();
                log(&format!(
                    "job {}: slot {}, K={}{}, {:.1}s left",
                    job.id,
                    job.slot,
                    job.k,
                    if job.control.beat.read().unwrap().is_some() { " (contested: must beat the best known output)" } else { "" },
                    job.control.deadline().saturating_duration_since(Instant::now()).as_secs_f64()
                ));
            }
            Ok(true) => log("no job: the miner is waiting"),
            Ok(false) => {},
            Err(e) => {
                log(&format!("REFUSING job {}: {e}", wire.id));
            }
        }
    }
}

fn install(w: &client::JobWire, pool: &IdentityPool) -> Result<Job, String> {
    let identity = pool.select(&w.pubkey)?;
    let alpha_prefix = job_protocol::validate_wire(w)?;
    Ok(Job {
        identity,
        id: w.id,
        slot: w.slot,
        alpha_prefix,
        k: w.k,
        control: job_protocol::JobControl::new(w)?,
    })
}

fn apply_job(shared:&Shared,pool:&IdentityPool,w:&client::JobWire)->Result<bool,String>{
    if w.id==0 {shared.refused_id.store(0,Ordering::Relaxed);let old=shared.job.write().unwrap().take();if let Some(job)=old.as_ref(){job.control.retire()};return Ok(old.is_some())}
    if shared.refused_id.load(Ordering::Relaxed)==w.id{return Err("job ID remains refused after inconsistent target".into())}
    shared.refused_id.store(0,Ordering::Relaxed);
    let incoming=match install(w,pool){Ok(job)=>job,Err(e)=>{shared.refused_id.store(w.id,Ordering::Relaxed);if let Some(old)=shared.job.write().unwrap().take(){old.control.retire()};return Err(e)}};
    let mut current=shared.job.write().unwrap();
    if let Some(old)=current.as_ref(){if old.id==w.id{
        if old.slot!=incoming.slot||old.k!=incoming.k||old.alpha_prefix!=incoming.alpha_prefix||old.identity.prover.public_key()!=incoming.identity.prover.public_key(){
            shared.refused_id.store(w.id,Ordering::Relaxed);old.control.retire();*current=None;return Err("same job ID changed its immutable VRF target".into())
        }
        old.control.refresh(w)?;return Ok(false)
    }}
    if let Some(old)=current.take(){old.control.retire()}
    *current=Some(Arc::new(incoming));Ok(true)
}

fn needs_gpu_reset(working:&Option<Arc<Job>>,current:&Arc<Job>)->bool{
    working.as_ref().map_or(true,|old|!Arc::ptr_eq(old,current))
}

fn finish_gpu_work(gpu:&mut gpu::Gpu,working:&mut Option<Arc<Job>>,shared:&Shared)->Result<(),String>{
    if let Some(old)=working.take(){
        let started=Instant::now();let attempts=gpu.drain_pending()?;let active_ns=started.elapsed().as_nanos()as u64;
        if attempts>0{shared.gpu_telemetry.lock().unwrap().record_job(old.identity.index,old.k,attempts,active_ns,true);shared.attempts.fetch_add(attempts,Ordering::Relaxed);}
    }Ok(())
}

fn gpu_worker(seed:&[u8;32],batch:usize,streams:usize,shared:&Shared,client:&Client,name:&str)->Result<(),String>{
    let mut gpu=gpu::Gpu::new_with_streams(seed,streams)?;
    log(&format!("GPU ready: {}, batch {batch}, streams {streams}; CPU checks every hit",gpu.device_name));
    let mut rng=rand::thread_rng();let mut working:Option<Arc<Job>>=None;let mut base=0u64;
    let mut active_seed=*seed;
    loop {
        let job=shared.job.read().unwrap().clone();
        let Some(job)=job else {finish_gpu_work(&mut gpu,&mut working,shared)?;thread::sleep(Duration::from_millis(50));continue};
        if !job.control.active() {finish_gpu_work(&mut gpu,&mut working,shared)?;thread::sleep(Duration::from_millis(50));continue}
        if needs_gpu_reset(&working,&job) {finish_gpu_work(&mut gpu,&mut working,shared)?;working=Some(job.clone());base=rng.gen();if active_seed!=job.identity.seed{gpu.set_seed(&job.identity.seed);active_seed=job.identity.seed;}gpu.set_job(&job.alpha_prefix,job.control.beat.read().unwrap().as_ref())?;}
        let search_start=Instant::now();
        let hit=gpu.search_batch(base,batch,job.k)?;
        let active_ns=search_start.elapsed().as_nanos() as u64;
        // Measurement v2 includes completed search calls and explicit old-job
        // drains, counted once each; setup time remains outside active_s.
        shared.gpu_telemetry.lock().unwrap().record_job(job.identity.index,job.k,batch as u64,active_ns,false);
        shared.attempts.fetch_add(batch as u64,Ordering::Relaxed);
        base=base.wrapping_add(batch as u64);
        if let Some((nonce,beta))=hit {
            // Never trust an accelerator result for a protocol submission.
            let mut alpha=job.alpha_prefix.clone();alpha.extend_from_slice(&nonce.to_be_bytes());
            if beta!=job.identity.prover.output(&alpha).0 || trailing_zero_bits(&beta)<job.k {return Err("GPU hit disagrees with CPU VRF reference".into())}
            let current=shared.job.read().unwrap().as_ref().map_or(false,|j|Arc::ptr_eq(j,&job));
            // In-flight batches may still use an earlier, weaker beat. That is
            // a normal beaten hit, not a CUDA correctness failure or a reset.
            if current && job.control.accepts(&beta) {
                let attempts=shared.attempts.swap(0,Ordering::Relaxed);submit(&job,nonce,&beta,attempts,client,name);
            }
        }
    }
}

/// One search thread. Each thread starts a job at its own random nonce and
/// walks its own residue class modulo the thread count, so threads never
/// repeat each other and neither do separate seekers under the same key.
fn worker(tid: usize, threads: usize, shared: &Shared, client: &Client, name: &str) {
    let mut rng = rand::thread_rng();
    let mut working: Option<Arc<Job>> = None;
    let mut nonce: u64 = 0;
    let mut alpha: Vec<u8> = Vec::new();
    loop {
        let job = shared.job.read().unwrap().clone();
        let Some(job) = job else {
            thread::sleep(Duration::from_millis(100));
            continue;
        };
        if !job.control.active() {
            thread::sleep(Duration::from_millis(100));
            continue;
        }
        if needs_gpu_reset(&working,&job) {
            working = Some(job.clone());
            nonce = rng.gen::<u64>().wrapping_add(tid as u64);
            alpha.clear();
            alpha.extend_from_slice(&job.alpha_prefix);
            alpha.extend_from_slice(&[0u8; 8]);
        }
        let n = alpha.len();
        let mut done = 0u64;
        for _ in 0..BATCH {
            nonce = nonce.wrapping_add(threads as u64);
            alpha[n - 8..].copy_from_slice(&nonce.to_be_bytes());
            let (beta, _) = job.identity.prover.output(&alpha);
            done += 1;
            if trailing_zero_bits(&beta) >= job.k && job.control.accepts(&beta) && shared.job.read().unwrap().as_ref().is_some_and(|current|Arc::ptr_eq(current,&job)) {
                let attempts = shared.attempts.swap(0, Ordering::Relaxed) + done;
                done = 0;
                submit(&job, nonce, &beta, attempts, client, name);
                break;
            }
        }
        shared.attempts.fetch_add(done, Ordering::Relaxed);
    }
}

fn submit(job: &Job, nonce: u64, beta: &[u8; 64], attempts: u64, client: &Client, name: &str) {
    match client.post_result(job.id, nonce, beta, attempts, name) {
        Ok(verdict)=>apply_verdict(job,nonce,beta,verdict),
        Err(e) => log(&format!("job {}: cannot post the solution: {e}", job.id)),
    }
}

fn apply_verdict(job:&Job,nonce:u64,beta:&[u8;64],verdict:Verdict){
    match verdict {
        Verdict::Accepted(beat) => {
            job.control.tighten(Some(*beta));job.control.tighten(beat);
            log(&format!("job {}: SOLVED with nonce {nonce:#018x}, accepted", job.id));
        }
        Verdict::Beaten(beat) => {job.control.tighten(Some(beat));},
        Verdict::Stale => {
            job.control.retire();
            log(&format!("job {}: solved, but the miner has moved on", job.id));
        }
        Verdict::Rejected(reason) => {
            // a disagreement about the work itself: keep searching, but say so
            log(&format!("job {}: REJECTED nonce {nonce:#018x}: {reason}", job.id));
        }
    }
}

#[cfg(test)]
#[path="../protocol_tests.rs"]
mod persistent_protocol_tests;

/// Reports the attempts once a second; the miner sizes its windows from them.
/// A failed report keeps its attempts for the next one.
fn reporter(shared: &Shared, client: &Client, name: &str) {
    let mut carried = 0u64;
    let mut window_start = Instant::now();
    let mut previous_gpu = GpuTelemetry::new(shared.gpu_telemetry.lock().unwrap().identities.len());
    let mut last_error = Instant::now() - RATE_LINE_EVERY;
    loop {
        thread::sleep(REPORT_EVERY);
        let n = shared.attempts.swap(0, Ordering::Relaxed) + carried;
        let id = shared.job.read().unwrap().as_ref().map_or(0, |j| j.id);
        carried = match client.post_report(id, n, name) {
            Ok(()) => 0,
            Err(e) => {
                if last_error.elapsed() >= RATE_LINE_EVERY {
                    log(&format!("cannot report attempts: {e}"));
                    last_error = Instant::now();
                }
                n
            }
        };
        if window_start.elapsed() >= RATE_LINE_EVERY {
            let elapsed = window_start.elapsed().as_secs_f64();
            let current_gpu = shared.gpu_telemetry.lock().unwrap().clone();
            let gpu_window = current_gpu.window(&previous_gpu);
            let delta_attempts = gpu_window.attempts;
            let active_secs = gpu_window.active_s;
            let state = shared.job.read().unwrap().as_ref().map_or("waiting", |j| {
                if !j.control.active() { "waiting" } else { "mining" }
            });
            let measured_at_ms = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_millis() as u64;
            let current_job=shared.job.read().unwrap().as_ref().map(|job|serde_json::json!({"id":job.id,"slot":job.slot,"k":job.k,"active":job.control.active()}));
            log(&format!("telemetry {}", serde_json::json!({
                "measurement_version":2,"current_job":current_job,
                "at_ms": measured_at_ms, "interval_s": elapsed,
                "session_started_at_ms": shared.session_started_at_ms,
                "pid": std::process::id(),
                "attempts": delta_attempts, "total_attempts": gpu_window.total_attempts,
                "active_s": active_secs, "total_active_s": gpu_window.total_active_s,
                "identities": gpu_window.identities,
                "difficulties":gpu_window.difficulties,
                "drain_attempts":gpu_window.drain_attempts,"total_drain_attempts":gpu_window.total_drain_attempts,
                "wall_hps": delta_attempts as f64 / elapsed,
                "active_hps": if active_secs > 0.0 { delta_attempts as f64 / active_secs } else { 0.0 },
                "active_percent": 100.0 * active_secs / elapsed,
                "state": state,
            })));
            window_start = Instant::now();
            previous_gpu = current_gpu;
        }
    }
}

/// Zero bits at the least significant end of beta, the last byte first: the
/// definition the mine lock enforces.
fn trailing_zero_bits(beta: &[u8]) -> u32 {
    let mut n = 0;
    for &b in beta.iter().rev() {
        if b == 0 {
            n += 8;
        } else {
            return n + b.trailing_zeros();
        }
    }
    n
}

fn log(msg: &str) {
    let secs = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
    println!("{:02}:{:02}:{:02} {msg}", secs / 3600 % 24, secs / 60 % 60, secs % 60);
}

#[cfg(test)]
mod tests {
    use super::*;
    use proxima_vrf::Prover;

    fn assert_gpu_snapshot_totals(snapshot: &GpuTelemetry) {
        assert_eq!(snapshot.totals.attempts, snapshot.identities.iter().map(|c| c.attempts).sum::<u64>());
        assert_eq!(snapshot.totals.active_ns, snapshot.identities.iter().map(|c| c.active_ns).sum::<u64>());
    }

    fn assert_gpu_window_totals(window: &GpuTelemetryWindow) {
        assert_eq!(window.attempts, window.identities.iter().map(|r| r["attempts"].as_u64().unwrap()).sum::<u64>());
        assert_eq!(window.total_attempts, window.identities.iter().map(|r| r["total_attempts"].as_u64().unwrap()).sum::<u64>());
        assert_eq!(window.active_s, window.identities.iter().map(|r| r["active_s"].as_f64().unwrap()).sum::<f64>());
        assert_eq!(window.total_active_s, window.identities.iter().map(|r| r["total_active_s"].as_f64().unwrap()).sum::<f64>());
    }

    #[test]
    fn gpu_identity_windows_preserve_idle_rows_and_cumulative_totals() {
        let zero = GpuTelemetry::new(8);
        let mut counters = zero.clone();
        counters.record(6, 131072, 9182731);
        counters.record(1, 131072, 10111213);
        counters.record(6, 131072, 8888888);
        assert_gpu_snapshot_totals(&counters);
        let first = counters.window(&zero);
        assert_gpu_window_totals(&first);
        assert_eq!(first.identities.len(), 8);
        assert_eq!(first.identities[6]["index"], 6);
        assert_eq!(first.identities[6]["attempts"], 262144);
        assert_eq!(first.identities[0]["attempts"], 0);
        let previous = counters.clone();
        counters.record(1, 1024, 1234567);
        let second = counters.window(&previous);
        assert_gpu_window_totals(&second);
        assert_eq!(second.attempts, 1024);
        assert_eq!(second.total_attempts, 394240);
        assert_eq!(second.identities[6]["attempts"], 0);
        assert_eq!(second.identities[6]["total_attempts"], 262144);
        let idle = counters.window(&counters);
        assert_gpu_window_totals(&idle);
        assert_eq!(idle.attempts, 0);
        assert_eq!(idle.active_s, 0.0);
        assert_eq!(idle.total_attempts, second.total_attempts);
    }

    #[test]
    fn gpu_completed_call_keeps_immutable_identity_after_job_replacement() {
        let wire = client::JobWire{id:11,alpha_prefix:"00".repeat(37),k:0,ttl_ms:2000,pubkey:hex::encode(Prover::from_seed(&[1;32]).public_key()),..Default::default()};
        let mut old = install(&wire, &IdentityPool::single([1;32])).unwrap();
        old.identity = Arc::new(MiningIdentity{index:6,seed:[1;32],prover:Prover::from_seed(&[1;32])});
        let mut current = install(&wire, &IdentityPool::single([1;32])).unwrap();
        current.identity = Arc::new(MiningIdentity{index:1,seed:[2;32],prover:Prover::from_seed(&[2;32])});
        let shared = Shared {
            job: RwLock::new(Some(Arc::new(current))),
            refused_id: AtomicU64::new(0),
            attempts: AtomicU64::new(0),
            gpu_telemetry: Mutex::new(GpuTelemetry::new(8)),
            session_started_at_ms: 1,
        };
        // A successful old search returns after the replacement was installed.
        shared.gpu_telemetry.lock().unwrap().record(old.identity.index, 131072, 9000000);
        let counters = shared.gpu_telemetry.lock().unwrap().clone();
        assert_gpu_snapshot_totals(&counters);
        assert_eq!(counters.identities[6].attempts, 131072);
        assert_eq!(counters.identities[1].attempts, 0);
        assert_eq!(shared.job.read().unwrap().as_ref().unwrap().identity.index, 1);
    }

    #[test]
    fn gpu_reporter_snapshots_cannot_split_aggregate_and_identity_updates() {
        let counters = Arc::new(Mutex::new(GpuTelemetry::new(8)));
        let worker_counters = counters.clone();
        let worker = thread::spawn(move || {
            for call in 0..10000 {
                worker_counters.lock().unwrap().record(call % 8, 1024, 17 + call as u64);
                if call % 100 == 0 { thread::yield_now(); }
            }
        });
        let mut previous = GpuTelemetry::new(8);
        for _ in 0..1000 {
            let snapshot = counters.lock().unwrap().clone();
            assert_gpu_snapshot_totals(&snapshot);
            assert_gpu_window_totals(&snapshot.window(&previous));
            previous = snapshot;
            thread::yield_now();
        }
        worker.join().unwrap();
        let final_snapshot = counters.lock().unwrap().clone();
        assert_gpu_snapshot_totals(&final_snapshot);
        assert_eq!(final_snapshot.totals.attempts, 10240000);
        assert_gpu_window_totals(&final_snapshot.window(&previous));
    }

    #[test]
    fn immutable_job_retains_identity_when_a_new_identity_job_arrives() {
        let pool_a=IdentityPool::single([1;32]);let pool_b=IdentityPool::single([2;32]);
        let mut wire=client::JobWire{id:11,alpha_prefix:"00".repeat(37),k:0,ttl_ms:2000,pubkey:hex::encode(Prover::from_seed(&[1;32]).public_key()),..Default::default()};
        let old=install(&wire,&pool_a).unwrap();wire.id=12;wire.pubkey=hex::encode(Prover::from_seed(&[2;32]).public_key());let current=install(&wire,&pool_b).unwrap();
        let alpha=[0u8;45];assert_eq!(old.identity.prover.output(&alpha).0,Prover::from_seed(&[1;32]).output(&alpha).0);assert_eq!(current.identity.prover.output(&alpha).0,Prover::from_seed(&[2;32]).output(&alpha).0);assert_ne!(old.identity.prover.output(&alpha).0,current.identity.prover.output(&alpha).0);
        assert!(install(&wire,&pool_a).is_err());
    }

    #[test]
    fn install_rejects_unknown_key_or_malformed_job_without_switching() {
        let pool=IdentityPool::single([3;32]);let mut wire=client::JobWire{id:1,alpha_prefix:"00".repeat(37),k:0,ttl_ms:2000,pubkey:"00".repeat(32),..Default::default()};assert!(install(&wire,&pool).is_err());
        wire.pubkey=hex::encode(pool.first().prover.public_key());wire.alpha_prefix="00".repeat(36);assert!(install(&wire,&pool).is_err());wire.alpha_prefix="00".repeat(37);wire.k=513;assert!(install(&wire,&pool).is_err());
    }

    #[test]
    #[ignore = "brief CUDA check using only fixed public fixture seeds"]
    fn cuda_switches_all_streams_for_eight_public_fixture_identities() {
        let started=Instant::now();let mut checked=0usize;
        let mut gpu=gpu::Gpu::new_with_streams(&[1;32],6).unwrap();
        let prefix=[7u8;37];
        for cycle in 0..2 {for index in 1..=8u8 {
            let seed=[index;32];gpu.set_seed(&seed);gpu.set_job(&prefix,None).unwrap();
            let reference=Prover::from_seed(&seed);
            for hit in gpu.verify_stream_hits(1000+cycle*10000,1024,0).unwrap() {
                let(nonce,beta)=hit.expect("K=0 fixture must yield a hit");let mut alpha=prefix.to_vec();alpha.extend_from_slice(&nonce.to_be_bytes());assert_eq!(beta,reference.output(&alpha).0);
                let proof=reference.prove(&alpha);assert_eq!(proxima_vrf::verify(reference.public_key(),&alpha,&proof).unwrap(),beta);checked+=1;
            }
            // Leave queued previous-key work; the next set_seed must drain it.
            assert!(gpu.search_batch(2000+cycle*10000,1024,512).unwrap().is_none());
        }}
        println!("public_cuda_identity_check {}",serde_json::json!({"identities":8,"streams":6,"cycles":2,"gpu_hits_checked":checked,"full_vrf_proofs_checked":checked,"explicit_gpu_buffer_bytes":gpu.explicit_buffer_bytes(),"elapsed_s":started.elapsed().as_secs_f64()}));
    }

    #[test]
    fn trailing_zeros_count_from_the_end() {
        assert_eq!(trailing_zero_bits(&[0xff, 0x00]), 8);
        assert_eq!(trailing_zero_bits(&[0x00, 0x01]), 0);
        assert_eq!(trailing_zero_bits(&[0x01, 0x00, 0x00]), 16);
        assert_eq!(trailing_zero_bits(&[0x80]), 7);
        assert_eq!(trailing_zero_bits(&[0x00; 3]), 24);
    }
}
