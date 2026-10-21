# Build and release notes

The Rust/CUDA implementation matches the recorded persistent-job seeker build.
Two source files have additional comment-only modification notices required for
license attribution; the other 19 selected inputs are byte-identical.
SOURCE-MANIFEST.json records both original build-input hashes and released-file
hashes. Packaging omits unused OpenCL experiments and operator files; it does not
change the CUDA search implementation or job protocol.

Recorded toolchain: rustc 1.99.0, cargo 1.99.0, x86_64-pc-windows-gnu,
LLVM-MinGW 20261006. The deployment build used target-cpu=native. The generic
build in README uses x86-64-v2 instead and is not claimed byte-identical.
Do not copy an old executable into a public release: it may embed build paths.

## Kernel source

seeker/src/kernel.cubin is the fixed SM86 CUDA module embedded with include_bytes!.
Its SHA256 is 1c1b68247039f7da1f741f8af7d0c759aaa8e90030f9b311c3e2c55f1a545d3b.
It contains compiled project code, not a private key or NVIDIA runtime.

To generate a fresh module, install NVRTC 12.4.127 and use:

```text
python scripts/build-kernel.py --nvrtc PATH_TO_NVRTC_SHARED_LIBRARY --output kernel-rebuilt.cubin
```

The helper refuses to overwrite an existing output and does not execute CUDA
on a GPU. Compare the new module with the included module before replacing it.
Different compiler versions and options need not be byte-identical. Rebuilt
kernels need the synthetic GPU correctness checks;
changing only the architecture flag is not a compatibility guarantee.

## Before creating a public release

1. Run the CPU/protocol tests and the GPU-only correctness tests on compatible hardware.
2. If rebuilding the kernel, verify every full beta and filtering boundary.
3. Scan the exact staged tree and any binaries for credentials and absolute build paths.
4. Keep all attribution/license notices. Do not add operator runtime directories.
5. Tag and publish only this clean tree, without private repository history.
