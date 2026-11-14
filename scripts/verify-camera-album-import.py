#!/usr/bin/env python3
"""Native regression from the open system Photos picker on iPhone 17e.

Use a Chinese DemoStudent build, open an unattached set's camera then Photos,
and identify the synthetic video's coordinates from a screenshot. --fixture is
that generated video. For --missing-source, --asset is its simulator DCIM copy:
the script verifies the exact bytes, moves only that synthetic copy aside, and
restores it in finally. No real account, video, or training record is required.
The backup remains beside the asset if the process is forcibly killed.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time


def nodes(value):
    if isinstance(value, list):
        for item in value:
            yield from nodes(item)
    elif isinstance(value, dict):
        yield value
        yield from nodes(value.get("children", []))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--axe", required=True)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--x", required=True, type=float)
    parser.add_argument("--y", required=True, type=float)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--missing-source", action="store_true")
    mode.add_argument("--expect-failure", action="store_true", help="Select a known rejected synthetic clip")
    mode.add_argument("--close-during-import", action="store_true",
                      help="Requires a slow provider; verifies close while loading and no late UI for 10s")
    parser.add_argument("--fixture", type=Path)
    parser.add_argument("--asset", type=Path)
    parser.add_argument("--evidence", type=Path, required=True)
    args = parser.parse_args()
    args.evidence.mkdir(parents=True, exist_ok=True)

    def axe(*command):
        return subprocess.check_output(
            [args.axe, *command, "--udid", args.udid], text=True, timeout=15
        )

    backup = None
    if args.missing_source:
        if not args.asset or not args.fixture:
            parser.error("--missing-source requires --asset and --fixture")
        asset = args.asset.resolve()
        expected_root = (
            Path.home() / "Library/Developer/CoreSimulator/Devices" / args.udid
            / "data/Media/DCIM"
        ).resolve()
        if not asset.is_relative_to(expected_root):
            parser.error("--asset must be in the selected simulator's DCIM")
        digest = hashlib.sha256(args.fixture.read_bytes()).digest()
        if hashlib.sha256(asset.read_bytes()).digest() != digest:
            parser.error("asset must exactly match the supplied synthetic fixture")
        backup = asset.with_suffix(asset.suffix + ".album-test-backup")
        if backup.exists():
            parser.error("backup already exists; restore it before retrying")
        asset.rename(backup)

    try:
        axe("tap", "-x", str(args.x), "-y", str(args.y), "--post-delay", "0.3")
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            tree = json.loads(axe("describe-ui"))
            visible = list(nodes(tree))
            labels = [item.get("AXLabel") or "" for item in visible]
            if args.close_during_import:
                if "正在读取视频…" not in labels:
                    time.sleep(0.1)
                    continue
                (args.evidence / "loading-ui.json").write_text(
                    json.dumps(tree, ensure_ascii=False, indent=2))
                close_buttons = [item for item in visible
                                 if item.get("type") == "Button"
                                 and item.get("AXLabel") == "关闭" and item.get("enabled")]
                if len(close_buttons) != 1:
                    raise AssertionError("Expected one enabled loading close button")
                frame = close_buttons[0]["frame"]
                axe("tap", "-x", str(frame["x"] + frame["width"] / 2),
                    "-y", str(frame["y"] + frame["height"] / 2), "--post-delay", "0.5")
                close_deadline = time.monotonic() + 10
                while time.monotonic() < close_deadline:
                    closed = json.loads(axe("describe-ui"))
                    closed_labels = [item.get("AXLabel") or "" for item in nodes(closed)]
                    if "编辑视频" in closed_labels or "相册" in closed_labels:
                        raise AssertionError("Closed import reopened its UI")
                    if "训练" not in closed_labels:
                        raise AssertionError("Close did not return to the training page")
                    time.sleep(0.2)
                (args.evidence / "closed-ui.json").write_text(
                    json.dumps(closed, ensure_ascii=False, indent=2))
                print("PASS: loading visible; close returned to training; no late UI for 10s")
                break
            if args.missing_source or args.expect_failure:
                passed = any(item.get("type") in ("Alert", "Sheet") for item in visible) and any(
                    "视频处理失败" in label for label in labels
                )
            else:
                passed = "上传" in labels and any("已选" in label for label in labels)
            if passed:
                (args.evidence / "ui.json").write_text(json.dumps(tree, ensure_ascii=False, indent=2))
                print("PASS: visible import failure" if args.missing_source or args.expect_failure else "PASS: trim ready")
                break
            time.sleep(0.2)
        else:
            (args.evidence / "ui.json").write_text(json.dumps(tree, ensure_ascii=False, indent=2))
            raise AssertionError(
                "No loading state observed" if args.close_during_import else
                "No import failure alert" if args.missing_source or args.expect_failure else "No trim screen")
    finally:
        if backup is not None:
            backup.rename(asset)
            if hashlib.sha256(asset.read_bytes()).digest() != digest:
                raise AssertionError("Restored fixture checksum changed")
            print("Synthetic source restored; SHA256 verified")


if __name__ == "__main__":
    main()
