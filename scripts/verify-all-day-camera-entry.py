#!/usr/bin/env python3
"""Native regression: run on a freshly launched Chinese DemoStudent on iPhone 17e.

Prerequisites: video consent already accepted, default demo cursor day visible,
and no modal open. No camera is simulated: this checks presentation of the real
recorder's unavailable state, including repeated close/reopen. It does not test
physical capture. Pass the installed AXe executable with --axe.
"""

import argparse
import json
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--axe", required=True)
    parser.add_argument("--udid", required=True)
    args = parser.parse_args()

    def axe(*command):
        return subprocess.check_output(
            [args.axe, *command, "--udid", args.udid], text=True, timeout=15
        )

    def nodes(value):
        if isinstance(value, list):
            for item in value:
                yield from nodes(item)
        elif isinstance(value, dict):
            yield value
            yield from nodes(value.get("children", []))

    def wait_for(key, value):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if any(node.get(key) == value for node in nodes(json.loads(axe("describe-ui")))):
                return
            time.sleep(0.2)
        raise AssertionError(f"Missing visible recorder control: {value}")

    expand = "allDay.expand.02400000-0000-0000-0000-000000030202"
    camera = "allDay.camera.02400000-0000-0000-0000-000000040220"
    wait_for("AXUniqueId", expand)
    axe("tap", "--id", expand, "--post-delay", "0.3")
    for attempt in range(1, 4):
        axe("tap", "--id", camera, "--post-delay", "0.5")
        wait_for("AXLabel", "相机不可用")
        wait_for("AXLabel", "关闭")
        axe("tap", "--label", "关闭", "--post-delay", "0.5")
        wait_for("AXUniqueId", camera)
        print(f"PASS {attempt}/3: recorder unavailable state visible; close returned to row")


if __name__ == "__main__":
    main()
