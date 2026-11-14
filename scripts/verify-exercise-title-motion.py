"""Check a stationary recording of one row switch. Exit 1 if the title leaves both endpoints.

Use the title's ink bounds in recording pixels (exclude the border and chevron).
Example for the 584px-wide DemoStudent pct-anchors capture:
  python3 scripts/verify-exercise-title-motion.py switch.mp4 87 818 596 90 26
"""
import argparse
import math
import statistics
import subprocess


def patches(video, x, y, width, height):
    data = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", video, "-vf",
        f"format=gray,crop={width}:{height}:{x}:{y}", "-fps_mode", "passthrough",
        "-f", "rawvideo", "-pix_fmt", "gray", "-",
    ])
    size = width * height
    return [data[i:i + size] for i in range(0, len(data), size)]


def normalized(patch):
    mean = statistics.mean(patch)
    centered = [value - mean for value in patch]
    norm = math.sqrt(sum(value * value for value in centered))
    return [value / norm for value in centered] if norm else [0] * len(patch)


def matches(patch, reference):
    return sum(a * b for a, b in zip(normalized(patch), reference)) >= 0.85


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video")
    for key in ("x", "old_y", "new_y", "width", "height"):
        parser.add_argument(key, type=int)
    args = parser.parse_args()
    if args.width <= 0 or args.height <= 0 or abs(args.old_y - args.new_y) < args.height:
        parser.error("use separate, nonempty title boxes")
    old, new = [patches(args.video, args.x, y, args.width, args.height)
                for y in (args.old_y, args.new_y)]
    if len(old) < 3 or len(old) != len(new):
        parser.error("record both settled states and the switch")
    reference = normalized(new[-1])
    states = [(matches(a, reference), matches(b, reference)) for a, b in zip(old, new)]
    if states[0] != (True, False) or states[-1] != (False, True):
        parser.error("title not found exclusively at the expected start and end positions")
    # A single switch goes directly from the old box to the new one; also reject
    # disappearance, duplication or a bounce back to the old box.
    switch = next(i for i, state in enumerate(states) if state != (True, False))
    bad = [i for i in range(switch, len(states)) if states[i] != (False, True)]
    print(f"{len(states)} frames; {len(bad)} invalid transition frames")
    return int(bool(bad))


if __name__ == "__main__":
    raise SystemExit(main())
