#!/bin/bash
# Temporary phase-1 probe. Green means not reproduced, not fixed.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_RUNNER_HANG_PROBE=1
export TEST_RUNNER_HANG_PROBE_SHEET="${HANG_PROBE_SHEET:-1}"
export TEST_RUNNER_HANG_PROBE_ITERATIONS="${HANG_PROBE_ITERATIONS:-24}"

# Debug is intentional: DemoStudent's hosted tests currently fail to link
# RepositoryContracts. The scheme and device match the original report.
exec /usr/bin/xcodebuild \
  -project "$repo_root/MeetPR.xcodeproj" \
  -scheme MeetPR-DemoStudent \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=A5119984-9A8D-415C-83D4-E7145351FA79' \
  -derivedDataPath /tmp/MeetPR-completion-hang-derived \
  -skipPackageUpdates \
  -parallel-testing-enabled NO \
  -only-testing:MeetPRTests/CompletionHangProbeTests \
  'OTHER_SWIFT_FLAGS=$(inherited) -D COMPLETION_HANG_PROBE' \
  test
