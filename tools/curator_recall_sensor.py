#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ДАТЧИК ОТЗЫВА ВЕРДИКТОВ.

Закрывает дыру, названную curator-0919 2026-10-14 общим открытым пунктом:
экзаменатор признал прибор негодным — а вердикты, выданные этим прибором,
остаются в силе, и предупредить их владельцев ничто не заставляет.

Связка из трёх полей:
  1. реестр отказов куратора: запись может нести поле  ПРИБОР: <имя>
  2. вердикт в шине: обязан нести строку               ПРИБОР: <имя> <блоб>
  3. предупреждение в шине: блок со строкой            ОТЗЫВ ПРИБОРА: <имя>

Красное, если прибор назван негодным, вердикты им выданы, а предупреждений
меньше, чем вердиктов. Датчик, не гейт: он не мешает выдать вердикт, он не
даёт отказу прибора остаться без оповещения.

Запуск: python3 tools/curator_recall_sensor.py [--self-test]
Прогоняется при КАЖДОМ подъёме куратора (§C его роль-скилла).
"""
import os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTER = os.path.join(ROOT, '.coord', 'protocols', 'standard-evidence.md')
INBOX_GLOB = os.path.join(ROOT, '.coord', 'inbox', '*.md')

RE_BAD_TOOL = re.compile(r'ПРИБОР-НЕГОДЕН:\s*([^\s|·]+)')
RE_VERDICT_TOOL = re.compile(r'^\s*ПРИБОР:\s*(\S+)\s+(\S+)', re.M)
RE_RECALL = re.compile(r'^\s*ОТЗЫВ ПРИБОРА:\s*(\S+)', re.M)
RE_BLOCK = re.compile(r'(?m)^## .*$')


def read(p):
    try:
        with open(p, encoding='utf-8') as f:
            return f.read()
    except OSError:
        return ''


def blocks(text):
    """Делит файл шины на блоки по заголовкам '## '."""
    idx = [m.start() for m in RE_BLOCK.finditer(text)]
    for i, s in enumerate(idx):
        e = idx[i + 1] if i + 1 < len(idx) else len(text)
        yield text[s:e]


def scan(register_text, inbox_files):
    bad = set(RE_BAD_TOOL.findall(register_text))
    verdicts, recalls = {}, {}
    for p in inbox_files:
        for b in blocks(read(p)):
            for name, _blob in RE_VERDICT_TOOL.findall(b):
                verdicts.setdefault(name, []).append(os.path.basename(p))
            for name in RE_RECALL.findall(b):
                recalls[name] = recalls.get(name, 0) + 1
    return bad, verdicts, recalls


def report(bad, verdicts, recalls, label):
    red = 0
    print('--- %s ---' % label)
    print('приборов, названных негодными в реестре: %d' % len(bad))
    print('приборов, которыми выданы вердикты:      %d' % len(verdicts))
    if not bad:
        print('нечего сверять: негодных приборов не названо -> ЗЕЛЕНО')
        return 0
    for name in sorted(bad):
        v = len(verdicts.get(name, []))
        r = recalls.get(name, 0)
        mark = 'ЗЕЛЕНО' if r >= v else '🔴 КРАСНОЕ'
        if r < v:
            red += 1
        print('  %-44s вердиктов %-3d предупреждений %-3d  %s'
              % (name, v, r, mark))
        if r < v:
            print('      владельцы, которым не сказано: %s'
                  % ', '.join(sorted(set(verdicts.get(name, [])))))
    return red


def main():
    inbox = sorted(glob.glob(INBOX_GLOB))
    print('ДАТЧИК ОТЗЫВА ВЕРДИКТОВ')
    print('реестр: %s' % os.path.relpath(REGISTER, ROOT))
    print('ящиков прочитано: %d   (положительный контроль: не 0)' % len(inbox))
    if not inbox:
        print('🔴 ящиков не найдено — датчик слеп, результат не засчитывается')
        return 2
    bad, verdicts, recalls = scan(read(REGISTER), inbox)
    red = report(bad, verdicts, recalls, 'ЖИВЫЕ ДАННЫЕ')

    # ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА: синтетика, на которой датчик ОБЯЗАН покраснеть.
    fake_reg = 'ПРИБОР-НЕГОДЕН: zzz-синтетический-прибор'
    fake_box = ('## вердикт\nПРИБОР: zzz-синтетический-прибор deadbeef\n'
                '## другой вердикт\nПРИБОР: zzz-синтетический-прибор deadbeef\n')
    b2, v2, r2 = set(RE_BAD_TOOL.findall(fake_reg)), {}, {}
    for b in blocks(fake_box):
        for n, _ in RE_VERDICT_TOOL.findall(b):
            v2.setdefault(n, []).append('синтетика')
    print()
    neg_red = report(b2, v2, r2, 'ОТРИЦАТЕЛЬНАЯ ПОЛОВИНА (обязана краснеть)')
    if neg_red == 0:
        print('🔴 ДАТЧИК НЕ УМЕЕТ КРАСНЕТЬ — его зелёное ничего не значит')
        return 2

    # и положительный контроль обратной стороны: с предупреждениями — зелено
    r3 = {'zzz-синтетический-прибор': 2}
    print()
    ok_green = report(b2, v2, r3, 'КОНТРОЛЬ: те же данные + 2 предупреждения')
    if ok_green != 0:
        print('🔴 ДАТЧИК КРАСНЕЕТ НА ИСПРАВНОМ — строже вопроса')
        return 2

    print()
    print('ИТОГ: живых красных %d · датчик краснеет на синтетике: да · '
          'зеленеет на исправном: да' % red)
    return 1 if red else 0


if __name__ == '__main__':
    sys.exit(main())
