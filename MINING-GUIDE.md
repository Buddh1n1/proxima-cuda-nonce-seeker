# Start mining on Windows, step by step

This guide uses one Windows PC, one SM86 NVIDIA GPU and a local Proxima miner.
The **official `proxi` miner** manages jobs and submits transactions. This
project's **CUDA seeker** does the GPU search. The job server is part of the
official miner; there is no separate server application to install.

## 1. Download the two programs

- Install an NVIDIA driver supporting CUDA 12.4. Run `nvidia-smi` in PowerShell
  to check the driver and GPU. See the [SM86 model list](README.md#sm86-gpu-models).
  This release needs 64-bit Windows and an x86-64-v2-capable CPU. It has no Linux
  backend. The CUDA toolkit and Rust are not needed to run the EXE.
- Download the Windows package containing `proxi.exe` from the
  [official Proxima releases](https://github.com/lunfardo314/proxima/releases).
  This guide was checked against v1.1.0-take1. Always use an official version
  compatible with the current network, including its ledger upgrades.
- Download `proxima-cuda-nonce-seeker-windows-x64-sm86.zip` and its
  `SHA256SUMS.txt` from [this project's releases](../../releases).
  Compare the ZIP hash with the published checksum:

  ```powershell
  Get-FileHash .\proxima-cuda-nonce-seeker-windows-x64-sm86.zip -Algorithm SHA256
  ```

## 2. Keep programs and your wallet separate

Extract the complete packages, retaining their licenses. Arrange them so the
two EXEs are at the paths below; release ZIPs may have an extra folder level.
Create a separate, initially empty `wallet` folder:

```text
C:\ProximaMining\
  proxi\proxi.exe
  gpu\nonce_seeker_cuda.exe
  wallet\
```

`C:\ProximaMining` is just an example. Do not put wallet files in a Git repository.

## 3. Create your mining wallet

Open PowerShell in the empty `wallet` folder:

```powershell
cd C:\ProximaMining\wallet
..\proxi\proxi.exe version
..\proxi\proxi.exe --verbose config wallet
```

The second command creates your `proxi.yaml` profile and `proxima.key` keystore.
Choose a passphrase when offered encryption and keep a secure backup of the key
and passphrase. Use a dedicated mining wallet rather than a wallet holding other
valuable assets. Never share or upload the key or passphrase.

If you already have a working mining wallet, use that profile and key instead;
skip wallet creation. Do not delete or replace an existing key to follow this
example. The miner and GPU seeker must use the same key.

## 4. Connect the official miner to a node

Edit `wallet\proxi.yaml` with a text editor. Under `api`, set `node_url` to a
working Proxima node API. The verbose generated profile contains commented
public-node URLs: choose a current access node from those or the
[official documentation](https://lunfardo314.github.io/). Keep the generated
`api.node_urls` witness list.

The default `http://127.0.0.1:8000` works only if you actually run a node there.
Using a public access node does not require running your own full node or sequencer.

In the same `proxi.yaml`, set the existing `mine.seeker` section as follows:

```yaml
mine:
  seeker:
    listen: "127.0.0.1:8100"
    token: ""
    spawn: false
```

Merge these settings into the existing section; do not create duplicate `mine`
or `api` sections. Keep your generated wallet and payout settings.

There are two different connections: `api.node_url` connects the miner to a
network node; `127.0.0.1:8100` connects the GPU seeker to the miner on this PC.

## 5. Check the profile before starting the GPU

Still in the `wallet` folder:

```powershell
..\proxi\proxi.exe node sync
..\proxi\proxi.exe wallet
..\proxi\proxi.exe node balance
```

The node should report `node synced: true`; repeat `node sync` after a short
interval and check that its reliable branch, or LRB, advances. `wallet` shows
your public wallet address. A new wallet can initially have no balance.
The official miner supports an opening payout for a previously unknown wallet;
this GPU seeker itself requires no activation payment or account funding.
You do not create a new mining chain: the miner uses the network's existing one.

## 6. Start the official miner — Terminal A

```powershell
cd C:\ProximaMining\wallet
..\proxi\proxi.exe node mine --workers 0
```

Keep this terminal open. Its startup banner should say it is serving
nonce-seeker jobs on `127.0.0.1:8100`. `--workers 0` leaves the search to the
external seeker. The miner still verifies results and submits transactions.

## 7. Start the GPU seeker — Terminal B

Open another PowerShell window, also in the `wallet` folder:

```powershell
cd C:\ProximaMining\wallet
..\gpu\nonce_seeker_cuda.exe --proxi http://127.0.0.1:8100 --key-file .\proxima.key --gpu --gpu-streams 6
```

Enter the keystore passphrase if requested. If your profile names a different
`wallet.key_file`, substitute that file path in the command. Quote paths with spaces.

`--proxi` points to Terminal A's local job server, not to the public node API.
There is no `--token` in this example because the local miner's token is empty.
If you choose a nonempty `mine.seeker.token`, add `--token "the-same-password"`
to the seeker command. This is a job-access password, not a wallet private key,
wallet passphrase, GitHub token or PROX token. Do not expose an unauthenticated
listener outside loopback; for a remote seeker use a protected connection and
a long random job password.

## 8. Check that it is working

- Terminal B should report `GPU ready`, then receive jobs. Its periodic telemetry
  should show increasing attempts and a nonzero `active_hps` while searching.
  `wall_hps` includes waiting time; the two rates can differ.
- `SOLVED ... accepted` means the miner accepted that result for its job. It does
  **not** mean a reward is confirmed. Terminal A tracks submitted, in-flight,
  confirmed and orphaned mining transactions; check its confirmed totals.
- Run `node balance` in a third terminal to inspect holdings. The standard
  miner may place rewards into delegations or top-ups according to the profile;
  not every confirmed reward becomes immediately liquid wallet balance.
  See the [official payout explanation](https://github.com/lunfardo314/proxima/blob/v1.1.0-take1/kb/mine_payout_options.md).

A quiet or waiting period can be normal. Finding a solution and winning its
conflict are different events; no fixed hashrate or reward rate is promised.

## 9. Stop and restart

Press `Ctrl+C` in Terminal B, then Terminal A. To resume, repeat steps 6 and 7.
Keep the same profile and key; wallet creation is a one-time step. This manual
two-terminal setup does not automatically restart either process after a reboot.

## Common problems

| Message or symptom | Check |
| --- | --- |
| `cannot reach the miner` | Terminal A is running; `mine.seeker.listen` and `--proxi` use the same local port. |
| HTTP 401 / `bad token` | Both sides use exactly the same job password, or omit `--token` when the miner token is empty. |
| `cannot load the key` | Correct key-file path, working directory and passphrase. Never paste a private key into an issue. |
| `REFUSING job` / unknown key | Miner and seeker must use the same wallet key and profile. |
| `GPU FATAL`, missing `nvcuda.dll` or kernel loading error | NVIDIA driver installed and GPU architecture matches the bundled SM86 kernel. Obtain drivers from NVIDIA, not DLL-download sites. |
| `no job: the miner is waiting` | Check Terminal A and the node's sync status; a short wait does not prove a GPU error. |
| Jobs work but no confirmed reward yet | Inspect actual attempts, difficulty and the miner's confirmations; acceptance by the local miner alone is insufficient. |

Official references: [external seeker configuration](https://github.com/lunfardo314/proxima/blob/v1.1.0-take1/kb/external_nonce_seeker.md),
[official reference seeker](https://github.com/lunfardo314/proxima/blob/v1.1.0-take1/proxi/node_cmd/mine/nonce_seeker/README.md).
This project has no custom node or sequencer requirement and includes no wallet,
preconfigured mining identity, private endpoint or credentials.
