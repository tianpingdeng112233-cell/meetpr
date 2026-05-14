#!/usr/bin/env python3
"""Import the coach-reviewed exercise library v2 xlsx into CoachKit JSON."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from xml.etree import ElementTree
from zipfile import ZipFile

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_XLSX = (
    Path.home()
    / "Brain/wiki/projects/MeetPR/domain/exercise-library-v2.xlsx"
)
DEFAULT_OUTPUT = (
    REPO_ROOT
    / "Modules/CoachKit/Sources/CoachKit/Resources/exercise-catalog-v2.json"
)
CATALOG_ROW_COUNT = 435

SPREADSHEET_NS = {
    "main": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "rel": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "pkgrel": "http://schemas.openxmlformats.org/package/2006/relationships",
}

TYPE_MAP = {
    "主项及变式": "main_lift_variation",
    "辅助项": "accessory",
    "热身": "accessory",
    "体能": "accessory",
    "举重": "accessory",
    "大力士": "accessory",
    "其他": "accessory",
}

LIFT_FAMILY_MAP = {
    "深蹲": "squat",
    "卧推": "bench",
    "硬拉": "deadlift",
}

EQUIPMENT_MAP = {
    "杠铃": "barbell",
    "哑铃": "dumbbell",
    "器械": "machine",
    "自重": "bodyweight",
    "绳索": "cable",
    "弹力带": "band",
    "壶铃": "kettlebell",
    "特殊杆": "specialty_bar",
    "其他": "other",
}

MOVEMENT_PATTERN_MAP = {
    "蹲": ["squat"],
    "水平推": ["horizontal_push"],
    "垂直推": ["vertical_push"],
    "髋铰链": ["hip_hinge"],
    "水平拉": ["horizontal_pull"],
    "垂直拉": ["vertical_pull"],
    "其他": ["other"],
}

MUSCLE_GROUP_MAP = {
    "quad": ["quad"],
    "hamstring": ["hamstring"],
    "shoulder": ["shoulder"],
    "chest": ["chest"],
    "core": ["core"],
    "back": ["back"],
    "glute": ["glute"],
    "arm-bicep": ["biceps"],
    "arm-tricep": ["triceps"],
    "arm-forearm": ["forearm"],
    "hip": ["hip"],
    "hip-flexor": ["hip_flexor"],
    "adductor": ["adductor"],
    "calf": ["calf"],
    "tibialis": ["tibialis"],
    "trap": ["trap"],
    "mobility": ["mobility"],
    "cardio": ["cardio"],
    "grip": ["grip"],
    "full-body": ["core", "back", "quad"],
    "post-chain": ["back", "hamstring", "glute"],
}

EXPECTED_HEADERS = [
    "#",
    "英文",
    "中文",
    "base",
    "大标签",
    "细标签",
    "器械",
    "动作模式",
    "主肌群",
    "stance",
    "grip",
    "tempo",
    "pause-pos",
    "其他修饰",
    "来源",
    "教练已审",
    "备注",
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xlsx", type=Path, default=DEFAULT_XLSX)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    rows = read_sheet(args.xlsx, "动作库")
    meta_rows = read_sheet(args.xlsx, "_meta")
    validate_source(rows, meta_rows)

    created_at = datetime.now(timezone.utc).replace(microsecond=0)
    created_at_json = created_at.strftime("%Y-%m-%dT%H:%M:%SZ")
    exercises = [exercise_from_row(row, created_at_json) for row in rows[1:]]
    validate_exercises(exercises)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(exercises, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"Wrote {len(exercises)} exercises to {args.output}")
    print(f"Exercise types: {Counter(item['exerciseType'] for item in exercises)}")
    print(f"Equipment: {Counter(e for item in exercises for e in item['equipment'])}")


def read_sheet(xlsx_path: Path, sheet_name: str) -> list[dict[str, str]]:
    with ZipFile(xlsx_path) as archive:
        sheet_path = sheet_xml_path(archive, sheet_name)
        shared_strings = read_shared_strings(archive)
        root = ElementTree.fromstring(archive.read(sheet_path))
        sheet_data = root.find("main:sheetData", SPREADSHEET_NS)
        if sheet_data is None:
            raise ValueError(f"{sheet_name} has no sheetData")

        rows: list[dict[str, str]] = []
        for row in sheet_data.findall("main:row", SPREADSHEET_NS):
            values: dict[str, str] = {}
            for cell in row.findall("main:c", SPREADSHEET_NS):
                values[column_name(cell.attrib["r"])] = cell_text(cell, shared_strings)
            rows.append(values)
        return rows


def sheet_xml_path(archive: ZipFile, sheet_name: str) -> str:
    workbook = ElementTree.fromstring(archive.read("xl/workbook.xml"))
    rels = ElementTree.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    rel_targets = {
        rel.attrib["Id"]: rel.attrib["Target"]
        for rel in rels.findall("pkgrel:Relationship", SPREADSHEET_NS)
    }

    for sheet in workbook.findall("main:sheets/main:sheet", SPREADSHEET_NS):
        if sheet.attrib["name"] == sheet_name:
            rel_id = sheet.attrib[f"{{{SPREADSHEET_NS['rel']}}}id"]
            target = rel_targets[rel_id].lstrip("/")
            return f"xl/{target}" if not target.startswith("xl/") else target

    raise ValueError(f"Sheet not found: {sheet_name}")


def read_shared_strings(archive: ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in archive.namelist():
        return []

    root = ElementTree.fromstring(archive.read("xl/sharedStrings.xml"))
    strings: list[str] = []
    for item in root.findall("main:si", SPREADSHEET_NS):
        strings.append("".join(text.text or "" for text in item.findall(".//main:t", SPREADSHEET_NS)))
    return strings


def column_name(cell_reference: str) -> str:
    return "".join(character for character in cell_reference if character.isalpha())


def cell_text(cell: ElementTree.Element, shared_strings: list[str]) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        node = cell.find("main:is/main:t", SPREADSHEET_NS)
        return node.text if node is not None and node.text is not None else ""

    value = cell.find("main:v", SPREADSHEET_NS)
    if value is None or value.text is None:
        return ""

    if cell_type == "s":
        return shared_strings[int(value.text)]

    return value.text


def validate_source(rows: list[dict[str, str]], meta_rows: list[dict[str, str]]) -> None:
    header = [rows[0].get(column, "") for column in columns_for_headers()]
    if header != EXPECTED_HEADERS:
        raise ValueError(f"Unexpected headers: {header}")

    data_rows = rows[1:]
    sequences = [int(row["A"]) for row in data_rows]
    expected_sequences = list(range(1, CATALOG_ROW_COUNT + 1))
    if sequences != expected_sequences:
        raise ValueError(
            f"Expected seq 1...{CATALOG_ROW_COUNT}, got {sequences[:3]}...{sequences[-3:]}"
        )

    meta_total = next(
        (row.get("B", "") for row in meta_rows if row.get("A", "") == "总条数"),
        "",
    )
    if int(meta_total) != CATALOG_ROW_COUNT:
        raise ValueError(f"Expected _meta 总条数={CATALOG_ROW_COUNT}, got {meta_total}")


def columns_for_headers() -> list[str]:
    return [chr(codepoint) for codepoint in range(ord("A"), ord("Q") + 1)]


def exercise_from_row(row: dict[str, str], created_at: str) -> dict[str, Any]:
    seq = int(row["A"])
    large_tag = row["E"]
    small_tag = row["F"]

    exercise_type = mapped(TYPE_MAP, large_tag, "大标签")
    main_lift_family = (
        mapped(LIFT_FAMILY_MAP, small_tag, "细标签")
        if large_tag == "主项及变式" and small_tag in LIFT_FAMILY_MAP
        else None
    )

    name_en = row.get("B", "").strip() or None

    return {
        "id": catalog_uuid(seq),
        "name": required(row, "C", "中文"),
        "nameEn": name_en,
        "exerciseType": exercise_type,
        "mainLiftFamily": main_lift_family,
        "isCompetitionLift": False,
        "muscleGroups": mapped(MUSCLE_GROUP_MAP, row["I"], "主肌群"),
        "equipment": [mapped(EQUIPMENT_MAP, row["G"], "器械")],
        "movementPattern": mapped(MOVEMENT_PATTERN_MAP, row["H"], "动作模式"),
        "createdByCoachId": None,
        "createdAt": created_at,
    }


def mapped(mapping: dict[str, Any], key: str, field: str) -> Any:
    if key not in mapping:
        raise ValueError(f"Unmapped {field}: {key}")
    return mapping[key]


def required(row: dict[str, str], column: str, field: str) -> str:
    value = row.get(column, "")
    if not value:
        raise ValueError(f"Missing required {field} at row {row.get('A', '?')}")
    return value


def catalog_uuid(seq: int) -> str:
    return f"00000000-0000-0000-ca70-{seq:012x}"


def validate_exercises(exercises: list[dict[str, Any]]) -> None:
    if len(exercises) != CATALOG_ROW_COUNT:
        raise ValueError(f"Expected {CATALOG_ROW_COUNT} exercises, got {len(exercises)}")

    ids = [exercise["id"] for exercise in exercises]
    if len(set(ids)) != len(ids):
        raise ValueError("Duplicate catalog UUIDs")

    expected_last_id = catalog_uuid(CATALOG_ROW_COUNT)
    if ids[-1] != expected_last_id:
        raise ValueError(f"Expected last ID {expected_last_id}, got {ids[-1]}")

    type_counts = Counter(exercise["exerciseType"] for exercise in exercises)
    if type_counts != Counter({"accessory": 322, "main_lift_variation": 113}):
        raise ValueError(f"Unexpected exercise type counts: {type_counts}")


if __name__ == "__main__":
    main()
