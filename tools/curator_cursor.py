# -*- coding: utf-8 -*-
"""Курсор прочтения: величина, которую нельзя поставить, не прочитав.

Метка роли ".read" врёт ровно там же, где врёт память: её ставят, не дочитав.
Курсор хранит ПОЗИЦИЮ и ХЕШ ЗАГОЛОВКА на этой позиции. Если в ящик дописали выше
курсора, переписали его или сдвинули — хеш не сойдётся, и позиция недействительна.

  stamp <роль> <строка>   поставить курсор (проверяет, что на строке действительно заголовок)
  check                   проверить все курсоры; печатает обе половины в одном прогоне
"""
import sys, io as _io, os, re, json, hashlib
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    sys.stdout = _io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

INBOX, CURS = ".coord/inbox", ".coord/cursors"
H = re.compile(r'^##\s')

def lines(p):
    return _io.open(p, encoding="utf-8", errors="replace").read().split("\n")

def sha(s):
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]

def stamp(role, n):
    p = os.path.join(INBOX, role + ".md"); L = lines(p); n = int(n)
    if not (1 <= n <= len(L)):
        print("СТОП: строки %d нет, в файле %d" % (n, len(L))); return 2
    if not H.match(L[n-1]):
        print("СТОП: на строке %d не заголовок, а: %s" % (n, L[n-1][:80])); return 2
    c = {"role": role, "line": n, "header_sha": sha(L[n-1]), "header": L[n-1][:120],
         "inbox_bytes": os.path.getsize(p), "total_headers": sum(1 for l in L if H.match(l))}
    _io.open(os.path.join(CURS, role + ".cursor"), "w", encoding="utf-8", newline="\n").write(
        json.dumps(c, ensure_ascii=False, indent=1))
    print("курсор %s -> строка %d, хеш %s" % (role, n, c["header_sha"])); return 0

def one(c, L):
    n = c["line"]
    if n > len(L):          return "🔴 файл короче курсора (%d < %d)" % (len(L), n), 0
    if sha(L[n-1]) != c["header_sha"]:
        return "🔴 ЗАГОЛОВОК НА СТРОКЕ %d ИЗМЕНИЛСЯ — курсор недействителен" % n, 0
    unread = sum(1 for l in L[n:] if H.match(l))
    return ("ЗЕЛЕНО · непрочитанных %d" % unread), unread

def check():
    print("КУРСОРЫ ПРОЧТЕНИЯ")
    cur = sorted(f for f in os.listdir(CURS) if f.endswith(".cursor")) if os.path.isdir(CURS) else []
    print("курсоров: %d   (положительный контроль: не 0)" % len(cur))
    if not cur:
        print("положительный контроль провален: проверять нечего"); return 2
    bad = 0
    for f in cur:
        c = json.load(_io.open(os.path.join(CURS, f), encoding="utf-8"))
        L = lines(os.path.join(INBOX, c["role"] + ".md"))
        v, _ = one(c, L)
        print("  %-14s строка %-6d %s" % (c["role"], c["line"], v))
        if v.startswith("🔴"): bad += 1
    L = ["## заголовок", "тело"]
    neg, _ = one({"line": 1, "header_sha": sha("## другой заголовок")}, L)
    pos, _ = one({"line": 1, "header_sha": sha("## заголовок")}, L)
    print("  отрицательная половина (подменённый заголовок): %s" % neg)
    print("  положительная половина (тот же заголовок):      %s" % pos)
    ok = neg.startswith("🔴") and pos.startswith("ЗЕЛЕНО")
    print("ИТОГ: недействительных курсоров %d · ловит подмену: %s" % (bad, "да" if ok else "НЕТ"))
    return 1 if (bad or not ok) else 0

if __name__ == "__main__":
    a = sys.argv[1:]
    sys.exit(stamp(a[1], a[2]) if a and a[0] == "stamp" else check())
