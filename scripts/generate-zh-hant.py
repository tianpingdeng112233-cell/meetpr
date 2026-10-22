#!/usr/bin/env python3
"""Regenerate spec 094 resources. Dev only: pip install -r scripts/zh-hant/requirements.txt.

Source: zh-Hans + GLOSSARY-zh-Hant.md. Never modifies existing locales or catalog data.
--check verifies committed output, placeholder identity, and simplified-only characters.
"""
import argparse
import copy
import json
import re
from pathlib import Path

import opencc
from opencc import OpenCC

ROOT = Path(__file__).resolve().parents[1]
CONVERTER = OpenCC('s2twp')
PLACEHOLDER = re.compile(r'%(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|[hljztL])?[@diuoxXfFeEgGaAcCsSpn%]|\{\{?[^{}]+\}?\}')


def glossary():
    result = {}
    source = (ROOT / 'specs/094-zh-hant/GLOSSARY-zh-Hant.md').read_text()
    for line in source.splitlines():
        if line.startswith('## 台湾动作写法别名'):
            break
        if not line.startswith('|'):
            continue
        cells = [c.strip() for c in line.split('|')[1:-1]]
        if len(cells) < 2 or cells[0] in ('简体源', '---') or cells[1] == '原样':
            continue
        left, right = cells[:2]
        if left.startswith('次数（') or left == 'N 次（reps 单位）':
            continue
        if left == '邮箱':
            result[left] = '信箱'
        elif left.startswith('周（'):
            result['周'] = '週'
        elif left.startswith('杆（'):
            result['杆'] = right
        elif left.startswith('杠杆（'):
            result['杠杆'] = right
        elif left == '个人记录 / 个人纪录 / 最佳纪录':
            result.update(dict.fromkeys(left.split(' / '), right))
        elif left in ('“ ”', '‘ ’'):
            result.update(zip(left.split(), right.split()))
        else:
            sources, targets = left.split(' / '), right.split(' / ')
            if len(targets) == 1:
                result.update(dict.fromkeys(sources, right))
            else:
                assert len(sources) == len(targets), (left, right)
                result.update(zip(sources, targets))
    # The approved v2 compound examples use 發布 for publishing a training plan.
    result.update({'发布训练计划': '發布課表', '发布计划': '發布課表'})
    return result


OVERRIDES = glossary()
WORDS = re.compile('|'.join(re.escape(w) for w in sorted(OVERRIDES, key=len, reverse=True)))
REPS_KEYS = set(json.loads((ROOT / 'scripts/zh-hant/reps-keys.json').read_text()))


def translate(text, key=None):
    # Reserve placeholders and glossary spans before OpenCC; longest source term wins.
    reserved = []

    def reserve(value):
        reserved.append(value)
        return f'ZXQRESERVED{len(reserved) - 1}QXZ'

    contextual = text.replace('次数', '下數').replace('次', '下') if key in REPS_KEYS else text
    protected = PLACEHOLDER.sub(lambda m: reserve(m[0]), contextual)
    protected = WORDS.sub(lambda m: reserve(OVERRIDES[m[0]]), protected)
    translated = CONVERTER.convert(protected)
    translated = re.sub(r'ZXQRESERVED(\d+)QXZ', lambda m: reserved[int(m[1])], translated)
    if text in ('邮箱', '邮箱地址', '请输入邮箱', '请输入邮箱地址'):
        translated = translated.replace('信箱', '電子郵件')
    assert PLACEHOLDER.findall(text) == PLACEHOLDER.findall(translated), text
    return translated


def translate_tree(value, catalog_key):
    if isinstance(value, dict):
        return {key: translate(item, key=catalog_key) if key == 'value' and isinstance(item, str)
                else translate_tree(item, catalog_key) for key, item in value.items()}
    if isinstance(value, list):
        return [translate_tree(item, catalog_key) for item in value]
    return value


def simplified_only():
    # OpenCC STCharacters: simplified keys minus ALL permitted traditional variants.
    # This excludes shared characters (e.g. 台, 周, 后), avoiding false positives.
    path = Path(opencc.__file__).parent / 'dictionary/STCharacters.txt'
    pairs = [line.split('\t') for line in path.read_text().splitlines() if '\t' in line]
    sources = {key for key, _ in pairs if len(key) == 1}
    targets = set(''.join(value.replace(' ', '') for _, value in pairs))
    targets.update(CONVERTER.convert(''.join(sorted(targets))))
    return ''.join(sorted(sources - targets)) + '\n'


def taiwan_aliases():
    source = (ROOT / 'specs/094-zh-hant/GLOSSARY-zh-Hant.md').read_text()
    section = source.split('## 台湾动作写法别名', 1)[1]
    result = []
    for line in section.splitlines():
        if not line.startswith('|'):
            continue
        cells = [cell.strip() for cell in line.split('|')[1:-1]]
        if cells[0].startswith(('别名', '---')):
            continue
        result.extend({'alias': alias, 'canonical': cells[1]} for alias in cells[0].split(' / '))
    return result


def main():
    check = argparse.ArgumentParser()
    check.add_argument('--check', action='store_true')
    args = check.parse_args()
    forbidden = set(simplified_only().strip())
    outputs = {ROOT / 'scripts/zh-hant/simplified-only.txt': simplified_only()}
    catalogs = sorted((ROOT / 'Modules').glob('*/Sources/*/Resources/*.xcstrings'))
    catalogs += [ROOT / 'MeetPR/Resources/Localizable.xcstrings',
                 ROOT / 'Widgets/MeetPRWidgets/Localizable.xcstrings']
    count = 0
    for path in catalogs:
        catalog = json.loads(path.read_text())
        for key, entry in catalog['strings'].items():
            entry['localizations']['zh-Hant'] = translate_tree(copy.deepcopy(entry['localizations']['zh-Hans']), key)
            count += 1
        outputs[path] = json.dumps(catalog, ensure_ascii=False, indent=2) + '\n'
    for path in (ROOT / 'MeetPR').glob('**/zh-Hans.lproj/InfoPlist.strings'):
        target = path.parent.parent / 'zh-Hant.lproj/InfoPlist.strings'
        outputs[target] = re.sub(r'(=\s*")(.*?)(";)',
                                 lambda m: m[1] + translate(m[2]) + m[3], path.read_text())
    catalog_path = ROOT / 'Modules/CoachKit/Sources/CoachKit/Resources'
    names = {entry['name'] for entry in json.loads((catalog_path / 'exercise-catalog-v2.json').read_text())}
    alias_path = catalog_path / 'exercise-aliases.json'
    alias_document = json.loads(alias_path.read_text())
    aliases = alias_document['aliases']
    for addition in taiwan_aliases():
        existing = next((alias for alias in aliases if alias['alias'] == addition['alias']), None)
        assert existing is None or existing == addition, addition
        if existing is None:
            aliases.append(addition)
    outputs[alias_path] = json.dumps(alias_document, ensure_ascii=False, indent=2) + '\n'
    for alias in aliases:
        names.update((alias['alias'], alias['canonical']))
    names.update(('比赛式深蹲', '比赛式卧推', '比赛式传统硬拉', '比赛式相扑硬拉', '卧推', '硬拉', '深蹲'))
    name_map = {name: translate(name) for name in sorted(names)}
    for source, target in name_map.items():
        assert not set(target) & forbidden, (source, target, set(target) & forbidden)
    resource_root = ROOT / 'Modules/CoreModels/Sources/CoreModels/Resources'
    outputs[resource_root / 'exercise-names-zh-Hant.json'] = json.dumps(name_map, ensure_ascii=False, indent=2) + '\n'
    # Runtime search needs no OpenCC library: generated Taiwan vocabulary and character map.
    reverse = {target: source for source, target in OVERRIDES.items() if source != target}
    reverse.update({'硬舉': '硬拉', '槓': '杠'})
    dictionaries = Path(opencc.__file__).parent / 'dictionary'
    chars = {}
    for line in (dictionaries / 'TSCharacters.txt').read_text().splitlines():
        if '\t' in line:
            key, values = line.split('\t')
            chars[key] = values.split()[0]
    reverse = {target: source for target, source in reverse.items()
               if ''.join(chars.get(char, char) for char in target) != source}

    def normalize_name(text):
        pattern = re.compile('|'.join(re.escape(key) for key in sorted(reverse, key=len, reverse=True)))
        text = pattern.sub(lambda match: reverse[match[0]], text)
        return ''.join(chars.get(char, char) for char in text)

    # Store only vocabulary that character folding + glossary cannot recover.
    # Keeping every full name here makes each keystroke scan thousands of redundant alternatives.
    for source, target in name_map.items():
        if normalize_name(target) != normalize_name(source):
            reverse[target] = source
    search_aliases = {}
    for alias in aliases:
        search_aliases.setdefault(alias['canonical'], []).append(alias['alias'])
    outputs[resource_root / 'exercise-search-zh-Hant.json'] = json.dumps(
        {'phrases': reverse, 'characters': chars, 'aliases': search_aliases}, ensure_ascii=False, indent=2) + '\n'
    for path, output in outputs.items():
        if path.suffix == '.xcstrings':
            def values(node):
                if isinstance(node, dict):
                    for key, val in node.items():
                        if key == 'value' and isinstance(val, str):
                            yield val
                        else:
                            yield from values(val)
            for entry in json.loads(output)['strings'].values():
                for val in values(entry['localizations']['zh-Hant']):
                    assert not set(val) & forbidden, (path, val, set(val) & forbidden)
        elif path.name == 'InfoPlist.strings':
            for val in re.findall(r'=\s*"(.*?)";', output):
                assert not set(val) & forbidden, (path, val, set(val) & forbidden)
        if args.check:
            assert path.exists() and path.read_text() == output, f'Stale generated file: {path}'
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(output)
    for source, target in OVERRIDES.items():
        if source != '邮箱':
            assert translate(source) == target, (source, target)
    print(f'{len(catalogs)} catalogs, {count} keys; placeholders, glossary, simplified-only scan OK')


if __name__ == '__main__':
    main()
