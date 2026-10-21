//! Synthetic public fixtures only. No key files and no CUDA initialization.
use super::*;
use proxima_vrf::Prover;
use std::io::{BufRead,Read,Write};
use std::net::TcpListener;

const FIXTURE_SEED:[u8;32]=[23;32];
fn wire(id:u64,slot:u32)->client::JobWire{
    let mut prefix=vec![7;33];prefix.extend_from_slice(&slot.to_be_bytes());
    client::JobWire{id,slot:slot as u64,alpha_prefix:hex::encode(prefix),pred:"07".repeat(33),k:0,ttl_ms:60_000,pubkey:hex::encode(Prover::from_seed(&FIXTURE_SEED).public_key()),..Default::default()}
}
fn shared()->Shared{Shared{job:RwLock::new(None),refused_id:AtomicU64::new(0),attempts:AtomicU64::new(0),gpu_telemetry:Mutex::new(GpuTelemetry::new(1)),session_started_at_ms:1}}
fn current(s:&Shared)->Arc<Job>{s.job.read().unwrap().as_ref().unwrap().clone()}

#[test]
fn gpu_single_key_mode_keeps_cpu_workers_zero_without_loading_a_key(){
    let cfg=parse_args_from(["--proxi","http://127.0.0.1:1","--gpu","--threads","0","--key-file","synthetic-not-opened.key"].map(str::to_string).into_iter()).unwrap();
    assert!(cfg.gpu);assert_eq!(cfg.threads,0);assert!(cfg.identities.is_none());assert_eq!(cfg.key_file,PathBuf::from("synthetic-not-opened.key"));
    let default=parse_args_from(["--proxi","http://127.0.0.1:1","--gpu"].map(str::to_string).into_iter()).unwrap();assert_eq!(default.threads,0);
}

#[test]
fn same_job_beat_refresh_preserves_arc_stream_ranges_and_absolute_deadline(){
    let pool=IdentityPool::single(FIXTURE_SEED);let s=shared();let mut w=wire(11,5000);
    assert!(apply_job(&s,&pool,&w).unwrap());let first=current(&s);let working=Some(first.clone());let deadline=first.control.deadline();
    w.beat=hex::encode([100;64]);w.ttl_ms=120_000;
    assert!(!apply_job(&s,&pool,&w).unwrap());assert!(Arc::ptr_eq(&first,&current(&s)));assert!(!needs_gpu_reset(&working,&current(&s)));assert_eq!(first.control.deadline(),deadline);
    w.beat=hex::encode([200;64]);apply_job(&s,&pool,&w).unwrap();assert_eq!(*first.control.beat.read().unwrap(),Some([100;64]));
    w.beat.clear();apply_job(&s,&pool,&w).unwrap();assert_eq!(*first.control.beat.read().unwrap(),Some([100;64]));
    w.ttl_ms=10;apply_job(&s,&pool,&w).unwrap();assert!(first.control.deadline()<deadline);
    first.control.retire();w.ttl_ms=120_000;apply_job(&s,&pool,&w).unwrap();assert!(!first.control.active());
}

#[test]
fn changed_slot_new_id_replaces_target_but_same_id_mutation_is_refused(){
    let pool=IdentityPool::single(FIXTURE_SEED);let s=shared();apply_job(&s,&pool,&wire(11,5000)).unwrap();let old=current(&s);
    assert!(apply_job(&s,&pool,&wire(12,5001)).unwrap());assert!(!old.control.active());assert!(needs_gpu_reset(&Some(old),&current(&s)));
    assert!(apply_job(&s,&pool,&wire(12,5002)).is_err());assert!(s.job.read().unwrap().is_none());
    assert!(apply_job(&s,&pool,&wire(12,5002)).is_err());assert!(s.job.read().unwrap().is_none());
    assert!(apply_job(&s,&pool,&wire(12,5001)).is_err());assert!(s.job.read().unwrap().is_none());
    // Server restart/no-job transitions may reuse an opaque number. Pointer identity still resets CUDA.
    apply_job(&s,&pool,&wire(1,5003)).unwrap();let first=current(&s);apply_job(&s,&pool,&client::JobWire::default()).unwrap();apply_job(&s,&pool,&wire(1,5004)).unwrap();assert!(needs_gpu_reset(&Some(first),&current(&s)));
}

#[test]
fn malformed_same_id_cannot_be_reinstalled_until_no_job_or_a_different_id(){
    let pool=IdentityPool::single(FIXTURE_SEED);let s=shared();apply_job(&s,&pool,&wire(11,5000)).unwrap();
    let mut bad=wire(11,5000);bad.k=513;assert!(apply_job(&s,&pool,&bad).is_err());
    assert!(apply_job(&s,&pool,&wire(11,5000)).is_err());assert!(s.job.read().unwrap().is_none());
    apply_job(&s,&pool,&client::JobWire::default()).unwrap();assert!(apply_job(&s,&pool,&wire(11,5000)).unwrap());
    bad.pubkey="00".repeat(32);assert!(apply_job(&s,&pool,&bad).is_err());
    assert!(apply_job(&s,&pool,&wire(12,5001)).unwrap());
}

#[test]
fn malformed_job_bounds_never_install(){
    let pool=IdentityPool::single(FIXTURE_SEED);
    for mutate in 0..9 {let mut w=wire(11,5000);match mutate{0=>w.k=513,1=>w.ttl_ms=0,2=>w.ttl_ms=-1,3=>w.ttl_ms=120001,4=>w.slot=u32::MAX as u64+1,5=>w.alpha_prefix="00".repeat(36),6=>w.pubkey="00".repeat(32),7=>w.pred="08".repeat(33),_=>w.beat="00".repeat(63)};assert!(install(&w,&pool).is_err(),"mutation {mutate}");}
}

#[test]
fn beaten_inflight_hits_are_normal_and_do_not_retire_the_job(){
    let pool=IdentityPool::single(FIXTURE_SEED);let job=install(&wire(11,5000),&pool).unwrap();
    apply_verdict(&job,1,&[200;64],Verdict::Accepted(Some([200;64])));assert!(job.control.active());
    apply_verdict(&job,2,&[100;64],Verdict::Accepted(Some([100;64])));assert!(job.control.active());
    assert!(!job.control.accepts(&[150;64]));assert!(job.control.accepts(&[50;64]));
    apply_verdict(&job,3,&[150;64],Verdict::Beaten([75;64]));assert!(job.control.active());assert_eq!(*job.control.beat.read().unwrap(),Some([75;64]));
    apply_verdict(&job,4,&[50;64],Verdict::Rejected("synthetic invalid proof".into()));assert!(job.control.active());
    apply_verdict(&job,4,&[50;64],Verdict::Stale);assert!(!job.control.active());
}

// Mirrors only kernel.cu:2096-2098, with constructed outputs providing an independent exact oracle.
fn kernel_filter_model(beta:&[u8;64],k:u32)->bool{
    let mut tz=0u32;for i in (0..64).rev(){let mut byte=beta[i];if byte==0{tz+=8;continue}while byte&1==0{tz+=1;byte>>=1;}break}tz>=k
}
#[test]
fn high_k_filter_has_no_32_or_64_bit_boundary_false_negatives(){
    for zeros in 0..=512usize{
        let mut beta=[0xffu8;64];for bit in 0..zeros {beta[63-bit/8]&=!(1u8<<(bit%8));}
        assert_eq!(trailing_zero_bits(&beta),zeros as u32);
        for k in [0,1,8,31,32,33,34,35,63,64,65,255,256,511,512] {
            assert_eq!(kernel_filter_model(&beta,k),zeros as u32>=k,"zeros={zeros},K={k}");
        }
    }
    // Real cryptographic outputs/proofs from public fixed seed, tested at the requested K boundaries.
    let prover=Prover::from_seed(&FIXTURE_SEED);
    for nonce in 0..32u64 {let mut alpha=hex::decode(wire(11,5000).alpha_prefix).unwrap();alpha.extend_from_slice(&nonce.to_be_bytes());let(beta,st)=prover.output(&alpha);assert_eq!(proxima_vrf::verify(prover.public_key(),&alpha,&prover.proof_for(&st)).unwrap(),beta);for k in [31,32,33,34,35,63,64]{assert_eq!(kernel_filter_model(&beta,k),trailing_zero_bits(&beta)>=k);}}
}

#[test]
fn six_stream_model_counts_completed_ranges_once_without_overcounting_initial_fill(){
    use std::collections::{HashSet,VecDeque};
    let batch=131072u64;let mut pending=VecDeque::new();let mut next=5000u64;let mut completed=HashSet::new();let mut reported=0u64;
    for lane in 0..6 {pending.push_back((lane,next));next+=batch;}
    for _ in 0..1000 {let(lane,base)=pending.pop_front().unwrap();assert!(completed.insert(base));reported+=batch;pending.push_back((lane,next));next+=batch;}
    assert_eq!(reported,1000*batch);assert_eq!(pending.len(),6);assert_eq!(next-5000,reported+6*batch);
    // set_job currently drains/discards these6 completed ranges without reporting them: undercount, not6x inflation.
    assert_eq!(pending.into_iter().map(|_|batch).sum::<u64>(),6*batch);
}

#[test]
fn used_difficulty_counters_include_old_job_drains_once_and_remain_bounded(){
    let initial=GpuTelemetry::new(1);let mut t=initial.clone();
    t.record_job(0,35,131072,1000,false);t.record_job(0,35,6*131072,2000,true);t.record_job(0,36,131072,1000,false);
    let w=t.window(&initial);assert_eq!(w.total_attempts,8*131072);assert_eq!(w.total_drain_attempts,6*131072);assert_eq!(w.difficulties.len(),2);assert_eq!(t.difficulties.len(),513);
    assert_eq!(w.difficulties.iter().map(|r|r["total_attempts"].as_u64().unwrap()).sum::<u64>(),w.total_attempts);
    assert_eq!(w.difficulties[0]["k"],35);assert_eq!(w.difficulties[0]["total_attempts"],7*131072);assert_eq!(w.difficulties[1]["k"],36);
    let idle=t.window(&t);assert_eq!(idle.attempts,0);assert_eq!(idle.drain_attempts,0);assert_eq!(idle.total_attempts,w.total_attempts);
}

#[test]
#[ignore="only after live GPU seeker is stopped; public64-nonce correctness fixture, no network or key files"]
fn cuda_public_64_nonce_full_beta_and_high_k_correctness(){
    let start=Instant::now();let prover=Prover::from_seed(&FIXTURE_SEED);let mut gpu=gpu::Gpu::new_with_streams(&FIXTURE_SEED,6).unwrap();
    let prefix=hex::decode(wire(11,5000).alpha_prefix).unwrap();let base=u64::MAX-31;let count=64;
    gpu.set_job(&prefix,None).unwrap();let actual=gpu.verify_outputs(base,count).unwrap();let mut expected=Vec::new();
    for index in 0..count{let mut alpha=prefix.clone();alpha.extend_from_slice(&base.wrapping_add(index as u64).to_be_bytes());let(beta,st)=prover.output(&alpha);assert_eq!(actual[index*65..index*65+64],beta);assert_eq!(actual[index*65+64]as u32,trailing_zero_bits(&beta).min(255));assert_eq!(proxima_vrf::verify(prover.public_key(),&alpha,&prover.proof_for(&st)).unwrap(),beta);expected.push(beta);}
    let mut checked=0;
    for k in [0,1,8,31,32,33,34,35,63,64]{
        let eligible=expected.iter().any(|b|trailing_zero_bits(b)>=k);
        for hit in gpu.verify_stream_hits(base,count,k).unwrap(){match hit{Some((nonce,beta))=>{let index=nonce.wrapping_sub(base)as usize;assert!(index<count);assert_eq!(beta,expected[index]);assert!(trailing_zero_bits(&beta)>=k);},None=>assert!(!eligible,"CUDA missed a qualifying public fixture, K={k}")};checked+=1;}
    }
    println!("public_cuda_v102_correctness {}",serde_json::json!({"nonces":count,"full_vrf_proofs":count,"streams":6,"filtered_stream_cases":checked,"targets":[0,1,8,31,32,33,34,35,63,64],"nonce_wraparound":true,"elapsed_s":start.elapsed().as_secs_f64(),"wallet_opened":false,"network":false}));
    assert!(start.elapsed()<Duration::from_secs(10),"fixture exceeded the bounded10-second test window");
}

#[test]
fn loopback_mock_persistent_job_accepts_multiple_verified_proofs_then_changes_slot(){
    let listener=TcpListener::bind("127.0.0.1:0").unwrap();let address=listener.local_addr().unwrap();
    listener.set_nonblocking(true).unwrap();
    let server=thread::spawn(move||{
        let prover=Prover::from_seed(&FIXTURE_SEED);let mut requests=0;let mut beat:Option<[u8;64]>=None;let mut proofs=0;let deadline=Instant::now()+Duration::from_secs(20);
        while requests<7{
            let(mut socket,_)=match listener.accept(){Ok(s)=>s,Err(e) if e.kind()==std::io::ErrorKind::WouldBlock=>{assert!(Instant::now()<deadline,"mock client stopped before all requests");thread::sleep(Duration::from_millis(2));continue},Err(e)=>panic!("{e}")};
            socket.set_read_timeout(Some(Duration::from_secs(5))).unwrap();let mut reader=std::io::BufReader::new(socket.try_clone().unwrap());
            let mut start=String::new();reader.read_line(&mut start).unwrap();let mut length=0;
            loop{let mut line=String::new();reader.read_line(&mut line).unwrap();if line=="\r\n"{break}if let Some((key,value))=line.split_once(':'){if key.eq_ignore_ascii_case("content-length"){length=value.trim().parse::<usize>().unwrap();}}}
            assert!(length<=4096);let mut body=vec![0;length];reader.read_exact(&mut body).unwrap();requests+=1;
            let mut status=200;
            let value=if start.starts_with("GET "){
                let w=wire(if requests<5{11}else{12},if requests<5{5000}else{5001});if requests>=5{beat=None};serde_json::json!({"id":w.id,"alpha_prefix":w.alpha_prefix,"slot":w.slot,"pred":w.pred,"k":w.k,"ttl_ms":w.ttl_ms,"pubkey":w.pubkey,"beat":beat.map(hex::encode).unwrap_or_default()})
            }else{
                let result:serde_json::Value=serde_json::from_slice(&body).unwrap();let expected_id=if requests<5{11}else{12};
                if result["id"]!=expected_id{status=409;serde_json::json!({"error":"stale job"})}
                else{
                    let nonce=hex::decode(result["nonce"].as_str().unwrap()).unwrap();assert_eq!(nonce.len(),8);
                    let w=wire(expected_id,if expected_id==11{5000}else{5001});let mut alpha=hex::decode(w.alpha_prefix).unwrap();alpha.extend_from_slice(&nonce);
                    let(beta,st)=prover.output(&alpha);assert_eq!(hex::encode(beta),result["beta"]);assert_eq!(proxima_vrf::verify(prover.public_key(),&alpha,&prover.proof_for(&st)).unwrap(),beta);proofs+=1;
                    let accepted=beat.map_or(true,|bar|beta<bar);if accepted{beat=Some(beta)}serde_json::json!({"accepted":accepted,"beat":hex::encode(beat.unwrap())})
                }
            };
            let text=value.to_string();write!(socket,"HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{text}",text.len()).unwrap();socket.flush().unwrap();
        }proofs
    });
    let client=Client::new(&format!("http://{address}"),None);let pool=IdentityPool::single(FIXTURE_SEED);let s=shared();
    let first=client.get_job(0,0).unwrap();apply_job(&s,&pool,&first).unwrap();let job=current(&s);let working=Some(job.clone());let initial_deadline=job.control.deadline();
    let mut alpha=job.alpha_prefix.clone();alpha.extend_from_slice(&0u64.to_be_bytes());let(first_beta,_)=job.identity.prover.output(&alpha);
    apply_verdict(&job,0,&first_beta,client.post_result(job.id,0,&first_beta,1,"synthetic").unwrap());assert!(job.control.active());
    let(mut nonce,mut smaller)=(1u64,first_beta);while smaller>=first_beta {alpha[37..].copy_from_slice(&nonce.to_be_bytes());smaller=job.identity.prover.output(&alpha).0;if smaller>=first_beta{nonce+=1};assert!(nonce<1000);}
    apply_verdict(&job,nonce,&smaller,client.post_result(job.id,nonce,&smaller,nonce,"synthetic").unwrap());assert!(job.control.active());assert!(!needs_gpu_reset(&working,&job));assert_eq!(job.control.deadline(),initial_deadline);
    let verdict=client.post_result(job.id,0,&first_beta,1,"synthetic").unwrap();assert!(matches!(verdict,Verdict::Beaten(_)));apply_verdict(&job,0,&first_beta,verdict);assert!(job.control.active());
    let next=client.get_job(job.id,0).unwrap();apply_job(&s,&pool,&next).unwrap();let next_job=current(&s);assert_eq!(next_job.slot,5001);assert!(!job.control.active());assert!(needs_gpu_reset(&working,&next_job));
    assert_eq!(client.post_result(job.id,0,&first_beta,1,"synthetic").unwrap(),Verdict::Stale);
    let mut next_alpha=next_job.alpha_prefix.clone();next_alpha.extend_from_slice(&0u64.to_be_bytes());let(beta,_)=next_job.identity.prover.output(&next_alpha);
    apply_verdict(&next_job,0,&beta,client.post_result(next_job.id,0,&beta,1,"synthetic").unwrap());assert!(next_job.control.active());
    assert_eq!(server.join().unwrap(),4);
}
