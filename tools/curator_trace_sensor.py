# -*- coding: utf-8 -*-
"""Датчик: отчёт обязан заканчиваться следом или названным ожиданием слова.
Читает ПОСЛЕДНИЙ блок каждого ящика шины. Зелёное — если в нём есть хотя бы одно из:
  - блоб/хеш (7+ hex), - путь с расширением, - число вида "до/было ... стало",
  - явное ожидание: "ждёт слова", "ждёт твоего слова", "нужно слово".
Красное — ни одного признака: ход закончен обещанием.
Печатает свою отрицательную половину и контроль «не строже вопроса» в том же прогоне.
"""
import sys, io as _io
# Консоль Windows по умолчанию cp1252/cp866 и падает на кириллице в print.
# Прибор, зелёный только в UTF-8 среде, негоден на машине оператора.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    sys.stdout = _io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = _io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

import os, re, sys, io

INBOX = ".coord/inbox"
RE_BLOB = re.compile(r'\b[0-9a-f]{7,40}\b')
RE_PATH = re.compile(r'[\w./-]+\.(md|py|ps1|cs|sql|json|log)\b')
RE_PAIR = re.compile(r'(было|до)\b.{0,80}?(стало|после)\b', re.S | re.I)
RE_WAIT = re.compile(r'жд[её]т\s+(твоего\s+)?слова|нужно\s+слово|ожидает\s+слова'
                     r'|останов(лен|ись|лено)\s+по\s+слову|остановись|до\s+слова\s+оператора', re.I)
# предмет нормы — ОТЧЁТ, а не всё, что лежит в шине.
# Отчёт опознаётся подписью роли в конце блока: "— <роль>-<4 цифры>".
RE_REPORT = re.compile(r'[—-]{1,2}\s*[a-z-]+-\d{4}\s*$', re.I | re.M)

def trace_signs(text):
    s = []
    if RE_BLOB.search(text): s.append("блоб")
    if RE_PATH.search(text): s.append("путь")
    if RE_PAIR.search(text): s.append("пара до/после")
    if RE_WAIT.search(text): s.append("названо ожидание слова")
    return s

def last_block(text):
    parts = re.split(r'\n---+\n|\n##\s', text)
    parts = [p for p in parts if p.strip()]
    return parts[-1] if parts else ""

def run(label, items):
    print("--- %s ---" % label)
    red = []
    for name, block in items:
        signs = trace_signs(block)
        verdict = ("ЗЕЛЕНО · " + ", ".join(signs)) if signs else "🔴 КРАСНОЕ · ход закончен обещанием"
        print("  %-22s хвост %5d симв · %s" % (name, len(block), verdict))
        if not signs: red.append(name)
    print("  красных: %d" % len(red))
    return red

if not os.path.isdir(INBOX):
    print("нет каталога %s" % INBOX); sys.exit(2)

items = []
skipped = []
for fn in sorted(os.listdir(INBOX)):
    if not fn.endswith(".md"): continue
    p = os.path.join(INBOX, fn)
    with io.open(p, "r", encoding="utf-8", errors="replace") as f:
        t = f.read()
    b = last_block(t)
    if len(b.strip()) < 120:
        skipped.append((fn, "пустой или служебный заголовок"))
        continue
    if not RE_REPORT.search(b):
        skipped.append((fn, "не отчёт: нет подписи роли"))
        continue
    items.append((fn, b))

print("ДАТЧИК СЛЕДА В ОТЧЁТЕ")
print("ящиков прочитано: %d · из них отчётов: %d · вне предмета: %d   (положительный контроль: отчётов не 0)"
      % (len(items) + len(skipped), len(items), len(skipped)))
for n, why in skipped:
    print("    вне предмета: %-22s %s" % (n, why))
if not items:
    print("положительный контроль провален: читать нечего"); sys.exit(2)
live = run("ЖИВЫЕ ДАННЫЕ", items)
syn_red = run("ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА (обязана краснеть)",
              [("zzz-обещание.md", u"Подниму письмо следующим шагом. Действую дальше, вернусь с результатом.")])
syn_green = run(u"КОНТРОЛЬ «не строже вопроса» (обязан зеленеть)",
                [("zzz-след.md", u"Записал в .coord/protocols/role-skill-standard.md, блоб 51818c46, было 97866 B стало 100509 B.")])
ok = (len(syn_red) == 1 and len(syn_green) == 0)
print("")
print("ИТОГ: живых красных %d · краснеет на обещании: %s · зеленеет на следе: %s"
      % (len(live), "да" if len(syn_red) == 1 else "НЕТ", "да" if len(syn_green) == 0 else "НЕТ"))
if not ok: print("ДАТЧИК НЕГОДЕН: не прошёл свои собственные половины")
