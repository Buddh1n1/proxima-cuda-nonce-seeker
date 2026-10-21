#[path="../gpu_cuda.rs"] mod gpu;
use proxima_vrf::Prover;
use sha2::{Digest,Sha512};
fn tz(beta:&[u8])->u32 {let mut n=0;for b in beta.iter().rev(){if *b==0{n+=8}else{return n+b.trailing_zeros()}}n}
fn main(){if let Err(e)=run(){eprintln!("{e}");std::process::exit(1)}}
fn run()->Result<(),String>{
    let args:Vec<String>=std::env::args().collect();let seconds=args.get(1).and_then(|s|s.parse::<f64>().ok()).unwrap_or(10.0);
    let batch=args.get(2).and_then(|s|s.parse::<usize>().ok()).unwrap_or(131072);
    let streams=args.get(4).and_then(|s|s.parse::<usize>().ok()).unwrap_or(6);
    println!("PID {}",std::process::id());
    let mut checked=0usize;
    let seed:[u8;32]=Sha512::digest(b"proxima offline GPU benchmark public test key 0")[..32].try_into().unwrap();
    let mut gpu=gpu::Gpu::new_with_streams(&seed,streams)?;println!("device {}, streams {streams}",gpu.device_name);
    for fixture in 0..8 {
        let seed:[u8;32]=Sha512::digest(format!("proxima offline GPU benchmark public test key {fixture}").as_bytes())[..32].try_into().unwrap();
        let prover=Prover::from_seed(&seed);gpu.set_seed(&seed);
        let mut prefix=[0u8;37];for (i,b) in prefix[..33].iter_mut().enumerate(){*b=(i*7+fixture*13)as u8;}prefix[33..].copy_from_slice(&(6000u32+fixture as u32).to_be_bytes());
        gpu.set_job(&prefix,None)?;
        let base=if fixture==7{u64::MAX-512}else{fixture as u64*1234567};
        let outputs=gpu.verify_outputs(base,1024)?;
        for i in 0..1024 {let nonce=base.wrapping_add(i as u64);let mut alpha=prefix.to_vec();alpha.extend_from_slice(&nonce.to_be_bytes());let beta=prover.output(&alpha).0;
            if outputs[i*65..i*65+64]!=beta || u32::from(outputs[i*65+64])!=tz(&beta).min(255){return Err(format!("VRF mismatch fixture {fixture}, nonce {nonce}"))}checked+=1;}
        // Every filtered candidate is rechecked against the independent Rust implementation.
        for beat in [None,Some([0x7fu8;64]),Some([0u8;64])] {
            gpu.set_job(&prefix,beat.as_ref())?;
            for hit in gpu.verify_stream_hits(base,16384,8)? {
            if let Some((nonce,beta))=hit {let mut alpha=prefix.to_vec();alpha.extend_from_slice(&nonce.to_be_bytes());
                if nonce.wrapping_sub(base)>=16384 || beta!=prover.output(&alpha).0 || tz(&beta)<8 || beat.map_or(false,|b|beta>=b){return Err("invalid filtered hit".into())}
            }else if beat!=Some([0u8;64]){return Err("expected easy target hit".into())}
            }
        }
        println!("fixture {fixture} OK");
    }
    println!("validated {checked} complete outputs + filter/beat tests with 8 keys and nonce wraparound");
    let seed:[u8;32]=Sha512::digest(b"proxima offline GPU benchmark public test key 0")[..32].try_into().unwrap();gpu.set_seed(&seed);
    let mut prefix=[0u8;37];for(i,b)in prefix[..33].iter_mut().enumerate(){*b=(i*7)as u8}prefix[33..].copy_from_slice(&6000u32.to_be_bytes());gpu.set_job(&prefix,None)?;
    let prover=Prover::from_seed(&seed);let mut boundary_checked=0;
    for count in [1,3,31,33,63,65,127,129,255,257,1023] {
        let outputs=gpu.verify_outputs(u64::MAX-16,count)?;
        for i in 0..count {let mut alpha=prefix.to_vec();alpha.extend_from_slice(&(u64::MAX-16).wrapping_add(i as u64).to_be_bytes());let beta=prover.output(&alpha).0;
            if outputs[i*65..i*65+64]!=beta || u32::from(outputs[i*65+64])!=tz(&beta).min(255){return Err("partial workgroup output mismatch".into())}boundary_checked+=1;
        }
    }
    println!("validated {boundary_checked} outputs in partial workgroups");
    println!("timing {seconds}s, batch {batch}");
    let(attempts,elapsed)=gpu.benchmark(seconds,batch)?;let rate=attempts as f64/elapsed;
    let report=serde_json::json!({"device":gpu.device_name,"pid":std::process::id(),"attempts":attempts,"seconds":elapsed,"attempts_per_second":rate,"batch":batch,"streams":streams,"filter_stream_checks":8*3*streams,"warmup_seconds":3,"variant":"CUDA SM86, six compact TAI passes plus complete fallback, packed equivalent NAF-5 scalar with folded final cofactor, two interleaved square pairs per point doubling and paired coordinate products, eight-round public-job SHA midstate, split root inversion, fused output filter, encoding block 128, configurable concurrent streams, no per-batch profiling","verified_full_outputs":checked,"partial_group_verified_outputs":boundary_checked,"explicit_gpu_buffers_bytes":gpu.explicit_buffer_bytes(),"result_readback_bytes_per_batch":80,"network_mining":false});
    println!("{rate:.0} full attempts/s ({:.3} MH/s)",rate/1e6);
    if let Some(path)=args.get(3){std::fs::write(path,serde_json::to_vec_pretty(&report).unwrap()).map_err(|e|e.to_string())?}Ok(())
}
