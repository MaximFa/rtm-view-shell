# -*- coding: utf-8 -*-
"""Датчик заявлений куратора: слово «сделал» обязано иметь след, которого раньше не было.

Мои ходы в чат на диск не ложатся — датчика на речь построить нельзя. Но каждое моё «сделал»
опирается либо на ран-бокс (транскрипт в .coord/measure/), либо на запись в ящик (пара до/после).
Значит проверяемо не то, ЧТО я сказал, а есть ли под словом след и НОВЕЕ ли он предыдущего.

Заявления веду в .coord/measure/curator-claims.tsv:   <utc>\t<тип: box|inbox|commit>\t<след>\t<что заявлено>
  box    -> имя файла транскрипта в .coord/measure/
  inbox  -> путь ящика (проверяется, что он новее предыдущего заявления)
  commit -> хеш коммита (проверяется, что объект существует)

Красное: след не существует, не новее предыдущего, или заявление без следа.
"""
import sys, io as _io, os, re, subprocess, datetime
try: sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception: sys.stdout = _io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

M, CL = ".coord/measure", ".coord/measure/curator-claims.tsv"

def mtime(p):
    return os.path.getmtime(p) if os.path.exists(p) else None

def judge(rows, label):
    print("--- %s ---" % label)
    bad, prev = 0, 0.0
    for ts, kind, trace, what in rows:
        if kind == "commit":
            ok = subprocess.run(["git","cat-file","-e",trace+"^{commit}"],capture_output=True).returncode == 0
            v = "ЗЕЛЕНО · коммит есть" if ok else "🔴 КОММИТА НЕТ"
            if not ok: bad += 1
        else:
            p = trace if kind == "inbox" else os.path.join(M, trace)
            t = mtime(p)
            if t is None:
                v = "🔴 СЛЕДА НЕТ НА ДИСКЕ"; bad += 1
            elif t < prev:
                v = "🔴 СЛЕД СТАРШЕ ПРЕДЫДУЩЕГО ЗАЯВЛЕНИЯ"; bad += 1
            else:
                v = "ЗЕЛЕНО · " + datetime.datetime.utcfromtimestamp(t).strftime("%Y-%m-%dT%H:%M:%SZ")
                prev = t
        print("  %s %-7s %-34s %s" % (ts, kind, trace[:34], v))
        print("        заявлено: %s" % what[:90])
    print("  красных: %d" % bad)
    return bad

if not os.path.exists(CL):
    _io.open(CL,"w",encoding="utf-8",newline="\n").write("")
rows = [l.rstrip("\n").split("\t") for l in _io.open(CL,encoding="utf-8") if l.strip() and not l.startswith("#")]
rows = [r for r in rows if len(r) == 4]
print("ДАТЧИК ЗАЯВЛЕНИЙ КУРАТОРА")
print("заявлений прочитано: %d   (положительный контроль: не 0)" % len(rows))
live = judge(rows, "ЖИВЫЕ ЗАЯВЛЕНИЯ") if rows else 0
if not rows: print("  положительный контроль провален: заявлений нет, судить нечего")
neg = judge([("2026-01-01T00:00:00Z","box","zzz-нет-такого-лога.log","синтетика: заявлено без следа")],
            "ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА (обязана краснеть)")
pos = judge([("2026-01-01T00:00:00Z","box","cur-cursor.log","синтетика: след существует")],
            "КОНТРОЛЬ «не строже вопроса» (обязан зеленеть)")
print()
print("ИТОГ: живых красных %d · краснеет на заявлении без следа: %s · зеленеет на следе: %s"
      % (live, "да" if neg == 1 else "НЕТ", "да" if pos == 0 else "НЕТ"))
