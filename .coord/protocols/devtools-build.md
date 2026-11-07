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
#    MANDATORY after every rsync: touch the files you changed. rsync -a preserves mtime,
#    so MSBuild sees an edited file as unchanged and does NOT rebuild it — the run then
#    shows reds from a defect you have already fixed, or greens on one still present.
#    Caught by backend-1015 2026-11-07 15:14Z, found only because the numbers disagreed.
mkdir -p ~/build/v4 && cd "$HOME/mnt/RTM-design" && rsync -a --delete --exclude='.git' --exclude='bin/' --exclude='obj/' --exclude='Installations/' --exclude='*.docx' --exclude='data-example/' --exclude='node_modules/' global.json CcDashboard.sln src tests RTM db deploy tools docs scripts infra ~/build/v4/
# 3. Env (every call)
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 NUGET_PACKAGES=$HOME/.nuget/packages
# 4. Restore (once, offline)
cd ~/build/v4 && ~/dotnet/dotnet restore CcDashboard.sln --source "$HOME/mnt/RTM View Shell/.devtools/nuget-packages"
# 5. Build — errors AND warnings. -clp:ErrorsOnly HIDES warnings: it is why two
#    local builds passed a change whose only defect was three new warnings.
cd ~/build/v4 && ~/dotnet/dotnet build CcDashboard.sln --no-restore -v q -clp:Summary -m 2>&1 | tee ~/build/warn-batch.txt
# then touch the changed files, rebuild, and compare warnings against base (see below)
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

## Warnings — compared, not read (asked by coordinator-1104 2026-11-07 21:27Z)

A build is not green because its tests are green. The devops Queue Report run went RED on
WARN NEW 3 alone (CS8714/CS8620 in a new guard file); both roles' local builds had compared
nothing, so the operator paid an extra round. Before handing over code:

```bash
# base: the tree as HEAD has it, built in a SEPARATE directory
mkdir -p ~/build/base && cd "$HOME/mnt/RTM-design" && git archive v4 | tar -x -C ~/build/base
cd ~/build/base && ~/dotnet/dotnet restore CcDashboard.sln --no-cache \
  --source "$HOME/mnt/RTM View Shell/.devtools/nuget-packages" >/dev/null
cd ~/build/base && ~/dotnet/dotnet build CcDashboard.sln --no-restore -v q -clp:Summary -m 2>&1 \
  | grep -oE '[^ /\\]+\.cs\([0-9]+,[0-9]+\): warning [A-Z]+[0-9]+: .*' \
  | sed -E 's/\(([0-9]+),([0-9]+)\)//' | sort -u > ~/build/warn-base.txt
# batch: the same filter over the build of your own tree (step 5)
grep -oE '[^ /\\]+\.cs\([0-9]+,[0-9]+\): warning [A-Z]+[0-9]+: .*' ~/build/warn-batch.txt \
  | sed -E 's/\(([0-9]+),([0-9]+)\)//' | sort -u > ~/build/warn-batch-k.txt
# the answer: expectation printed before the measurement
echo "expected WARN NEW 0"; comm -13 ~/build/warn-base.txt ~/build/warn-batch-k.txt | tee /dev/stderr | wc -l
```

Line numbers are stripped on purpose: a warning that merely moved down the file is not new.
Comparison is by (file, code, text).

**Both sides must be non-empty.** An empty `warn-base.txt` and an empty `warn-batch-k.txt`
produce WARN NEW 0 on total absence — a false green. Print both line counts beside the
verdict; if either is 0, that is RED "not measured", not zero.

**Negative half, run every time, not reasoned about.** Add a known warning to a copy in the
batch tree (an unused variable, or `#pragma warning` removed) and re-run the comparison: it
must print 1. A comparison that cannot return red does not count. Then remove it and confirm
the count is back to 0.

How devops counts WARN NEW in the engine is his number — take the exact rule from him rather
than inventing a second one here; if the two disagree, his is the gate and this one is wrong.
