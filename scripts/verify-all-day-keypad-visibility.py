"""Exercise the bottom set of a freshly launched Chinese DemoStudent (-student-empty-state pct-anchors)."""
import argparse
import json
import subprocess
import time


def descendants(node):
    yield node
    for child in node.get("children", []):
        yield from descendants(child)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--axe", required=True)
    parser.add_argument("--udid", required=True)
    args = parser.parse_args()

    def axe(*command):
        return subprocess.check_output([args.axe, *command, "--udid", args.udid], timeout=15)

    def tap(identifier):
        axe("tap", "--id", identifier, "--wait-timeout", "3", "--post-delay", "0.2")

    def controls():
        return {
            node["AXUniqueId"]: node
            for root in json.loads(axe("describe-ui")) for node in descendants(root)
            if node.get("AXUniqueId")
        }

    def visible_editor(field_label, expected=None, previous=None):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            layout = controls()
            cells = [key for key in layout if key.startswith("allDay.cell.")]
            ids = {key.split(".")[2] for key in cells}
            panel = layout.get("workout.keypad")
            if len(cells) == 3 and len(ids) == 1 and panel:
                row = ids.pop()
                frames = [layout[key]["frame"] for key in cells]
                bottom = max(frame["y"] + frame["height"] for frame in frames)
                top = panel["frame"]["y"]
                visible = min(frame["y"] for frame in frames) >= 0 and bottom <= top
                focused = (panel.get("AXLabel") or "").endswith(field_label)
                if visible and focused and (expected is None or row == expected) and row != previous:
                    print(f"{row} {field_label}: fields end at {bottom:.1f} pt, keypad starts at {top:.1f} pt")
                    return row
            time.sleep(0.15)
        raise AssertionError(f"Expected all three fields above the keypad: {cells}, {panel}")

    row = "07200000-0000-0000-0000-000000000301"
    tap("allDay.expand.07200000-0000-0000-0000-000000000003")
    tap(f"allDay.row.{row}")
    visible_editor("重量 kg", expected=row)
    for _ in range(2):
        tap("numberPad.add")
        row = visible_editor("重量 kg", previous=row)
    for field, label in (("reps", "次数"), ("rpe", "RPE")):
        tap(f"allDay.cell.{row}.{field}")
        visible_editor(label, expected=row)
    tap("numberPad.dismiss")
    assert "workout.keypad" not in controls()


if __name__ == "__main__":
    main()
