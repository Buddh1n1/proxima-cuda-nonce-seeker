use proxima_vrf::Prover;
use sha2::{Digest, Sha512};
use std::sync::{Arc, Barrier};
use std::time::{Duration, Instant};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let seconds: u64 = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(5);
    let label = args.get(2).map(String::as_str).unwrap_or("rust");
    let threads: Vec<usize> = args.get(3).unwrap_or(&"1,12,20,24".into())
        .split(',').map(|s| s.parse().unwrap()).collect();
    let report = args.get(4);
    let mut rows = Vec::new();
    for count in threads {
        assert!(count > 0);
        let barrier = Arc::new(Barrier::new(count + 1));
        let mut workers = Vec::new();
        for tid in 0..count {
            let barrier = barrier.clone();
            workers.push(std::thread::spawn(move || {
                let digest = Sha512::digest(b"proxima offline GPU benchmark public test key 0");
                let mut seed = [0u8;32];seed.copy_from_slice(&digest[..32]);
                let prover = Prover::from_seed(&seed);
                let mut alpha = [0u8;45];
                for (i,b) in alpha[..33].iter_mut().enumerate() {*b=(i*7) as u8;}
                alpha[33..37].copy_from_slice(&6000u32.to_be_bytes());
                for n in 0u64..512 {alpha[37..].copy_from_slice(&n.to_be_bytes());std::hint::black_box(prover.output(&alpha).0);}
                barrier.wait();
                let deadline = Instant::now() + Duration::from_secs(seconds);
                let mut attempts = 0u64;
                let mut checksum = 0u64;
                let mut nonce = tid as u64;
                while Instant::now() < deadline {
                    for _ in 0..64 {
                        alpha[37..].copy_from_slice(&nonce.to_be_bytes());
                        let beta = std::hint::black_box(prover.output(&alpha).0);
                        let mut zeroes = 0u32;
                        for b in beta.iter().rev() {if *b==0 {zeroes+=8;} else {zeroes+=b.trailing_zeros();break;}}
                        checksum = checksum.wrapping_add(zeroes as u64);
                        attempts += 1;
                        nonce = nonce.wrapping_add(count as u64);
                    }
                }
                (attempts,checksum)
            }));
        }
        barrier.wait();
        let start = Instant::now();
        let mut attempts=0u64;let mut checksum=0u64;
        for w in workers {let (n,c)=w.join().unwrap();attempts+=n;checksum=checksum.wrapping_add(c);}
        let elapsed=start.elapsed().as_secs_f64();
        let rate=attempts as f64/elapsed;
        println!("{label}: {count} threads, {rate:.0} full attempts/s, {elapsed:.3}s, checksum {checksum}");
        rows.push(serde_json::json!({"threads":count,"attempts":attempts,"seconds":elapsed,"attempts_per_second":rate,"checksum":checksum}));
    }
    if let Some(path)=report {std::fs::write(path,serde_json::to_vec_pretty(&serde_json::json!({"label":label,"cpu":"AMD Ryzen 9 5900X","measurement":"offline complete ECVRF Output and trailing-zero count, synthetic fixture, warmup before each case","rows":rows})).unwrap()).unwrap();}
}
