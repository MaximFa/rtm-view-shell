# .probes — measurement scripts I hand to the operator

The reverse direction of `.measurements/`: **out** to a server, where that folder is **in**.

## Why this exists

Pasting a 100-line run-box into the chat costs context twice — once when I write it, once when the
console echoes it back. The operator asked (2026-09-05) for the box to travel as a FILE instead:
I write it here, he copies it to the server, runs one short line, and brings back the output.

## The flow, fixed

1. I write `probe_<SERVER>_<YYYYMMDD_HHMMSS>_<topic>.ps1` into this folder.
2. Operator copies it to `C:\RTMView-Ops\incoming\` on that server.
   That ops root exists on every deployed server by project convention (CLAUDE.md §43:
   `incoming\` = scripts staged to apply, `output\` = reports and logs). Nothing new is invented.
3. Operator runs ONE line (the probe prints it back too):

       Get-ChildItem C:\RTMView-Ops\incoming\*.ps1 | Unblock-File
       powershell -ExecutionPolicy Bypass -File C:\RTMView-Ops\incoming\<probe>.ps1

   `Unblock-File` is not optional: a .ps1 that travelled from another machine carries the
   mark-of-the-web and PowerShell refuses it as unsigned (standing deploy trap, role-devops §B).
4. The probe writes its output into `C:\RTMView-Ops\output\` and prints the exact paths.
5. Operator copies those into `.measurements/` here, under the naming convention in its README.

## Rules for every probe file

- **UTF-8 WITH BOM + CRLF.** Windows PowerShell 5.1 decodes a BOM-less file by the ANSI codepage;
  any non-ASCII byte then breaks a string literal and the script dies with a ParserError
  (CLAUDE.md §35; role-devops §B 2026-07-13). Verify first bytes are `EF BB BF`.
- **Read-only unless the task says otherwise**, and it says so in its own header.
- **Self-describing:** first line printed is WHERE IT RUNS — machine, database, read-or-write.
- **The gate is inside the probe**, not in the operator's head: exit code, stderr size as a
  CONDITION, end-of-run marker, negative controls printed explicitly. Last line says PASS or FAIL.
- **Never a password prompt in the clear**, and never a password echoed: read it from the
  machine's own config, print only its length.
- A re-run gets a NEW file name with a new timestamp — never an overwrite of an existing probe.

## A probe that CREATES something leaves its mark next to it (added 2026-09-12, devops-0912)

Measured cost, not theory: on 2026-09-12 two of my probes were each executed twice. Both first runs
completed and created their directories; both second runs hit `must NOT exist yet` and refused. The gate
was right to refuse - an existing artifact is never silently reused - but it could only say "this exists",
never "this is MY OWN previous result". Two extra operator turns were spent establishing by file
timestamps what the probe could have stated itself.

Rules from that, for every probe that creates a directory, a package or any other artifact:

- **Stamp the name.** A created directory carries the run stamp (`..._<yyyyMMdd_HHmmss>`), so two runs of
  one probe never collide in the first place.
- **Write an `.origin` file inside what you create**, one line: probe file name, probe sha256, run stamp,
  machine, and the revision the artifact was made from. The data is already printed in the report - the
  point is that it lives NEXT TO the artifact, which is what the next run can read.
- **On "it already exists", read the mark and distinguish three cases**: my own previous run (say so,
  print its stamp, and let the operator choose re-use or a fresh stamped name) / another probe's artifact
  (do not touch) / no mark at all, so the origin is unknown (do not touch, and say which of the three it
  is). "Exists" alone is not an answer.
- **The first section of the report says what the probe FOUND on entry**, before its first write - existing
  directories and their marks - not only what it did.
- Never delete or overwrite an artifact you did not create in this run, with or without a mark.


## ПОМЕТКИ ПО ИТОГАМ ПРОГОНА ШЛЮЗА (2026-09-19, devops-0916)

Весь реестр — 158 пробов — прогнан через `tools/lint_probe.py` и парсер pwsh 7.
Ни один проб не правлен и не перезапущен. Пометки ниже — решение `coordinator-0917` от 19.09:
пометить дешевле и честнее, чем пере-прогонять задним числом: проба — инструмент, а не запись, и её
сегодняшний прогон измерил бы СЕГОДНЯШНЮЮ площадку, а не ту, на которой принималось решение.

### НЕ ИСПОЛНЯЕМ ВООБЩЕ — не запускать, не чинить

- `probe_LOCAL_20260908_seqfix-proof-v3.ps1` — **не разбирается парсером** (строка 218:
  `Unexpected token 'means'` / `Missing closing ')'`; бисекция: до 200 строк разбирается, после нет).
  В `.measurements` есть `seqfix-proof`, `-v2` и `-v4`, а `v3` нет вовсе — то есть он ни разу не
  отработал, и следом родился `v4`. Лежал рядом с рабочими без всякой пометы одиннадцать дней.
  **Не чинить:** чинить проб, чей результат никому не нужен, — работа ради симметрии.

### СОДЕРЖИТ КЛАСС, НЕ ПРОВЕРЯВШИЙСЯ ПРИ ИСПОЛЬЗОВАНИИ (2026-09-19)

Одна и та же переменная записана в двух регистрах **в одной области видимости** — в PowerShell это
ОДНА переменная, и одна из двух ролей могла молча затереть другую. Проверено по АСТ (pwsh 7),
а не регуляркой: из 19 помеченных линтером — 14 настоящих, 3 безобидных (разные области).

**Граница пометки, дословно:** не «их результаты неверны», а «их зелёное никто не проверял
на этот класс».

| проб | столкнувшиеся имена |
|---|---|
| `probe_234_20260907_wipe-step4-v2.ps1` | `$Extra` / `$extra` |
| `probe_234_20260908_state.ps1` | `$L` / `$l` |
| `probe_234_20260912_preinstall-state.ps1` | `$L` / `$l` |
| `probe_234_20260913_early-ask.ps1` | `$NEG` / `$neg` |
| `probe_234_20260913_routine-sets.ps1` | `$psql` / `$PSQL` |
| `probe_234_20260914_resub-experiment.ps1` | `$PORT` / `$port` |
| `probe_234_20260914_signalr-owner.ps1` | `$psql` / `$PSQL` |
| `probe_234_20260916_inst13-DE.ps1` | `$BK` / `$bk` |
| `probe_234_20260916_inst13-step0.ps1` | `$a` / `$A` |
| `probe_234_20260919_deploy0ae2102-step2-install.ps1` | `$L` / `$l` — именно этот случай стоил отчёта в 3 байта |
| `probe_DEV_20260906_halt-test-step4.ps1` | `$B` / `$b` |
| `probe_DEV_20260907_halt-test-step4-v2.ps1` | `$B` / `$b` |
| `probe_DEV_20260907_halt-test-step4-v3.ps1` | `$B` / `$b` |
| `probe_DEV_20260916_141213_inst13-dry-ADE.ps1` | `$V` / `$v` |

Безобидные (разные области, внутренняя — новая локальная, родительская не трогается):
`probe_234_20260917_inst14-D.ps1`, `probe_234_20260917_inst14-D2.ps1`, `probe_234_20260918_cmp01-detail.ps1`.

### ОТРИЦАТЕЛЬНЫЙ КОНТРОЛЬ ШЛЮЗА

- `probe_NEGCTL_gate_must_fail.ps1` — **НИКОГДА не выдавать оператору и не запускать.**
  По одной намеренной ошибке на каждый класс, который шлюз обязан ловить. Шлюз, никогда ничего
  не уронивший, неотличим от выключенного. Проверка: `python3 tools/lint_probe.py .probes/probe_NEGCTL_gate_must_fail.ps1`
  обязана дать 8 FAULT и `DO NOT HAND OUT`.
