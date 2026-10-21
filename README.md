# Proxima CUDA nonce seeker

A Windows x86-64 external nonce seeker for Proxima's `proxi node mine` job server.
Rust handles jobs, key loading and CPU verification; a CUDA kernel searches VRF
nonces on an NVIDIA GPU. The miner completes proofs and publishes transactions.
This is an unofficial implementation, not a node, wallet application or sequencer.

## What is included

- Persistent jobs: stricter beat updates preserve the running search and its deadline.
- Immutable job identity, bounded job leases and stale-result rejection.
- CPU verification of accelerator hits before sending results to the miner.
- Six CUDA streams by default, configurable from one to eight.
- Search-time, wall-time, per-difficulty and per-identity telemetry.
- Protocol tests with synthetic keys and a loopback mock server.

No deployment configuration, wallet, credentials, real addresses, operator logs or
Git history are included. Test seeds in source are public synthetic fixtures;
never fund or reuse them.

## Requirements and limitations

- Windows x86-64; NVIDIA driver supporting CUDA 12.4 and an SM86 GPU.
- The bundled kernel targets SM86 (for example RTX 3090), not arbitrary GPUs.
- Rust 1.99.0 GNU was used for the recorded build. A compatible GNU linker is needed.
- This backend links `nvcuda.dll`; Linux CUDA support is not implemented here.
- The kernel is supplied as CUDA source and a fixed, hashed CUBIN. It does not
  install a CUDA toolkit or change GPU clocks, power limits or fan settings.
- This package has not been validated against future miner protocols or forks.
  The external job protocol is distinct from transaction/ledger versioning.

## Build

For a ready-to-run Windows build, open this repository's **Releases** page and
download `proxima-cuda-nonce-seeker-windows-x64-sm86.zip`. Extract the ZIP, check
its `SHA256SUMS.txt`, and run `nonce_seeker_cuda.exe` using the example below.
You still need an NVIDIA driver and your own compatible mining job server;
Rust and the CUDA toolkit are not needed to run the packaged executable.

### SM86 GPU models

NVIDIA lists these GPUs as compute capability **8.6** (`sm_86`):

| Family | Models |
| --- | --- |
| GeForce | RTX 3090 Ti, 3090, 3080 Ti, 3080, 3070 Ti, 3070, 3060 Ti, 3060, 3050 Ti, 3050 |
| Workstation | RTX A6000, RTX A5000, RTX A4000, RTX A3000, RTX A2000 |
| Data center | A40, A10, A16, A2 |

Source: [NVIDIA CUDA GPU compute capability list](https://developer.nvidia.com/cuda/gpus).
This is an architecture list, not a claim that each model has been tested with
this seeker. The backend has been operated on an RTX 3090; performance, memory,
driver and Windows support vary by model. Check the exact desktop/laptop SKU.
The packaged build has no Linux backend. RTX 40/50 series and A100/A30 are not
SM86 models; this release does not claim support for them.

```powershell
rustup toolchain install stable-x86_64-pc-windows-gnu
$env:RUSTFLAGS = '-C link-self-contained=yes -C target-cpu=x86-64-v2'
cargo +stable-x86_64-pc-windows-gnu build --release --locked -p nonce_seeker --bin nonce_seeker_cuda
```

If needed, set `CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER` to your installed
MinGW-w64 GCC. Executables are separate release assets, not source-tree files.
See [BUILD.md](BUILD.md) for kernel rebuilding and provenance limits.

## Use

The GPU seeker does not connect to a sequencer directly. It asks your local
`proxi node mine` process for search jobs. Run the miner and seeker in two
terminals on the same Windows PC:

1. First make sure your normal `proxi` wallet profile and node connection work.
   In that profile's `proxi.yaml`, merge the following into `mine` (keep your
   existing wallet, node and mining-target settings):

   ```yaml
   mine:
     seeker:
       listen: "127.0.0.1:8100"
       token: ""
       spawn: false
   ```

   `127.0.0.1` means this PC only. The empty token in this local example is
   intentional. Do not expose an unauthenticated listener to a network.

2. Start the miner in the directory containing your normal profile:

   ```powershell
   proxi node mine --workers 0
   ```

   Its banner should say it is serving nonce-seeker jobs on `127.0.0.1:8100`.
   `--workers 0` leaves the search to the GPU seeker.

3. In a second terminal, open the extracted release folder and start:

```powershell
.\nonce_seeker_cuda.exe --proxi http://127.0.0.1:8100 --key-file "C:\path\to\your\proxima.key" --gpu --gpu-streams 6
```

Replace the example key-file path with **your miner's existing local keystore
file**, the path configured as `wallet.key_file`. The miner and seeker need the
same mining key. Never use a key supplied by someone else's example. An
encrypted key file will request its passphrase. A source build puts the EXE
under `target\release\` instead of the extracted release folder.

### What does `--token` mean?

It is an optional **shared access password for the miner's job server**. It is
not a wallet private key, seed, GitHub token or PROX token. You choose this
password yourself; it is not downloaded or obtained from a sequencer.

If you set a nonempty `mine.seeker.token` in the miner's profile, add
`--token "the-same-password"` to the seeker command. Both values must match
exactly; otherwise the miner rejects the connection with HTTP 401. If the
miner has an empty token, as in the loopback-only example above, omit the
entire `--token` option. Do not literally enter `YOUR_JOB_TOKEN`.

For connections between different machines, use a long random password and a
trusted private network or protected tunnel; the job protocol is plain HTTP.
Keep the job password private and separate from your wallet passphrase. The
token authorizes job/result access; it does not replace the local mining key
required for the seeker's VRF computations.

The seeker needs the mining key internally for VRF computation. Use only on a
trusted local machine/GPU. Do not publish key files, passphrases, environment
variables or command-line tokens. Restrict the miner's job server to a trusted
interface. `--gpu-batch` accepts 1024 through 131072. GPU mode defaults to zero
CPU search threads. Running without the required options prints usage.

## Tests

```powershell
cargo +stable-x86_64-pc-windows-gnu test --locked -p proxima-vrf --lib
cargo +stable-x86_64-pc-windows-gnu test --locked -p proxima-keystore --lib
cargo +stable-x86_64-pc-windows-gnu test --locked -p nonce_seeker --bin nonce_seeker_cuda
```

Ordinary tests do not initialise CUDA or use real wallet files. Two GPU checks
are explicitly ignored by default; run them only on an otherwise idle compatible
GPU, using `--ignored --test-threads=1`. They use public synthetic keys. Passing
protocol tests does not establish live-network acceptance or a mining profit rate.

## License and attribution

Retain [LICENSE](LICENSE), [NOTICE](NOTICE) and [LICENSES](LICENSES) when
redistributing. The Rust crates declare Apache-2.0; Proxima-derived portions,
curve25519-dalek and ref10 arithmetic retain their respective notices. This is
not an official Proxima release or an endorsement by upstream authors.
