<!-- Перенесён из .coord/devtools-build.md куратором 2026-11-07.
     Причина: на него ссылаются норма стандарта и навык shell, то есть это НОРМАТИВНЫЙ документ,
     а не состояние. В .coord/ он попадал под `*` из .gitignore и жил в одном экземпляре.
     Источник замера — coordinator-1104, письмо 2026-11-07T13:18:03Z, блоб 61942758.
     КАНОНИЧЕСКИЙ ПУТЬ ТЕПЕРЬ ЭТОТ. -->

# Local build in the bridge VM (no network) — recipe
Author: coordinator-1104, 2026-11-07. Operator's decision 13:42 (+02:00): «давай 2» — SDK and NuGet packages in a folder on disk.
Source: `D:\Claude\Projects\RTM View Shell\.devtools\` (git-excluded via .git/info/exclude): dotnet-sdk-8.0.427-linux-x64.tar.gz (sha512 matched Microsoft's release metadata), nuget-packages\ (299 ids, 1.8 GB, copy of the operator's %USERPROFILE%\.nuget\packages).
Measured by coordinator-1104 on 2026-11-07: unpack 14 s; copy of the tree 45 s; offline restore 58 s; full build 2 min 40 s, 0 errors; Unit 10 s; Architecture 2 s. Integration/Security need Docker — not here, those stay with devops.

## Rules
- Build in YOUR VM copy, never in D:\Claude\Projects\RTM-design: obj/ and bin/ from Linux must not land in the shared worktree.
- Every bridge call is ≤ 180 s: one step per call (the full first build fits; later builds are incremental and faster).
- This is your own pre-check before handing over, not a replacement for devops' run (base/batch, warnings diff, controls, tested tree).
- Print the expected before the measured: «errors expect 0», «failed expect 0».

## Steps (bash on the bridge)
```bash
# 1. SDK (once per session)
mkdir -p ~/dotnet && tar -xzf "$HOME/mnt/RTM View Shell/.devtools/dotnet-sdk-8.0.427-linux-x64.tar.gz" -C ~/dotnet && ~/dotnet/dotnet --version   # expect 8.0.427
# 2. Copy / refresh the tree (rsync — repeat after every edit; only changes travel)
mkdir -p ~/build/v4 && cd "$HOME/mnt/RTM-design" && rsync -a --delete --exclude='.git' --exclude='bin/' --exclude='obj/' --exclude='Installations/' --exclude='*.docx' --exclude='data-example/' --exclude='node_modules/' global.json CcDashboard.sln src tests RTM db deploy tools docs scripts infra ~/build/v4/
# 3. Env (every call)
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 NUGET_PACKAGES=$HOME/.nuget/packages
# 4. Restore (once, offline)
cd ~/build/v4 && ~/dotnet/dotnet restore CcDashboard.sln --source "$HOME/mnt/RTM View Shell/.devtools/nuget-packages"
# 5. Build — all errors
cd ~/build/v4 && ~/dotnet/dotnet build CcDashboard.sln --no-restore -v q -clp:ErrorsOnly -m
# 6. Tests that run without Docker
cd ~/build/v4 && ~/dotnet/dotnet test tests/CcDashboard.Tests.Unit --no-build -v q
cd ~/build/v4 && ~/dotnet/dotnet test tests/CcDashboard.Tests.Architecture --no-build -v q
# one failing test in detail
~/dotnet/dotnet test tests/CcDashboard.Tests.Unit --no-build --filter 'FullyQualifiedName~<TestName>' --logger 'console;verbosity=detailed'
```
If restore says a package is missing from the folder — write to coordinator with the id and version (the operator adds it); do not try the network.

## Disk — shared by ALL bridge sessions (measured 2026-11-07 coordinator-1104)
The VM disk `/sessions` is ONE 9.8 GB disk for every bridge session on this machine. One full setup costs ~2.6 GB per session: SDK 0.6 GB + restored packages 1.5 GB (~/.nuget) + tree and bin/obj ~0.5–1 GB. At 12:14Z free space fell to 1.5 GB with two setups on it.
- Only roles that change code set it up (backend, shell). Coordinator, devops, curator — not.
- One copy per session; no second tree.
- Keep the setup for the WHOLE session: unpack and restore once, then only rsync + incremental build before each hand-over. Remove it only when the session ends (handoff to a successor) or when the coordinator asks for space: `rm -rf ~/dotnet ~/.nuget ~/build`, `df -h /sessions` before/after.
- Before setup: `df -h /sessions` — under 3 GB free → write to coordinator, do not start.
- Pointing NUGET_PACKAGES at the folder on D: (to avoid the 1.5 GB copy) was tried: restore over the mount did not finish in 3 minutes — not usable.
