// Cold-launch regression for functions.exec; evaluate this expression and call (tools, options).
// Requires MeetPR-Demo built with COACH_LAUNCH_HANG_TESTING and XcodeBuildMCP defaults set.
// A green result alone means not reproduced, not fixed. No user credentials are used.
(async (tools, { name = "probe", fixture = true, screenshot = false, extraArgs = [] } = {}) => {
  if (!/^[a-z0-9-]+$/.test(name)) throw new Error("Invalid evidence name");
  const root = "/Users/david/Projects/apps/MeetPR-wt-coach-launch-hang";
  const directory = `${root}/docs/evidence/coach-launch-hang`;
  const path = `${directory}/${name}.txt`;
  await tools.mcp__XcodeBuildMCP__stop_app_sim({});
  await tools.exec_command({
    cmd: `python3 -c 'import pathlib,sys; pathlib.Path(sys.argv[1]).unlink(missing_ok=True)' '${path}'`,
    max_output_tokens: 100
  });
  const started = Date.now();
  const launchArgs = ["-coach-launch-hang-probe", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"];
  if (fixture) launchArgs.push("-coach-launch-hang-fixture");
  launchArgs.push(...extraArgs);
  const launch = await tools.mcp__XcodeBuildMCP__launch_app_sim({
    launchArgs, env: { COACH_HANG_PROBE_OUTPUT: path }
  });
  if (launch.structuredContent?.didError) throw new Error("Launch failed");
  const assertion = await tools.exec_command({
    cmd: `python3 -c 'import pathlib,sys,time; p=pathlib.Path(sys.argv[1]); end=time.monotonic()+8
while not p.exists() and time.monotonic()<end: time.sleep(0.05)
s=p.read_text() if p.exists() else "HARNESS ERROR: no watchdog result"; print(s.strip()); sys.exit(0 if "PASS mainResponse=" in s else 1 if "FAIL mainResponse>3s" in s else 2)' '${path}'`,
    max_output_tokens: 200
  });
  const watchdogWallMs = Date.now() - started;
  const snapshot = await tools.mcp__XcodeBuildMCP__snapshot_ui({});
  const screen = snapshot.structuredContent?.data?.capture;
  const fixtureLoaded = !fixture || [...(screen?.targets ?? []), ...(screen?.text ?? [])]
    .some(row => row.includes("Demo · D4"));
  if (assertion.exit_code === 0 && !fixtureLoaded) assertion.exit_code = 2;
  let tapResponseMs = null;
  const ref = snapshot.structuredContent?.data?.capture?.targets
    ?.find(row => row.split("|")[3] === "Profile")?.split("|")[0];
  if (assertion.exit_code === 0 && !ref) assertion.exit_code = 1;
  if (screenshot) {
    const capture = await tools.mcp__XcodeBuildMCP__screenshot({ returnFormat: "base64" });
    const image = capture.content.find(item => item.type === "image");
    if (image) await tools.exec_command({
      cmd: `python3 -c 'import base64,pathlib,sys; pathlib.Path(sys.argv[1]).write_bytes(base64.b64decode(sys.argv[2]))' '${directory}/${name}.jpg' '${image.data}'`,
      max_output_tokens: 100
    });
  }
  if (assertion.exit_code === 0 && ref) {
    const tapStart = Date.now();
    await tools.mcp__XcodeBuildMCP__tap({ elementRef: ref });
    const response = await tools.mcp__XcodeBuildMCP__wait_for_ui({
      predicate: "exists", identifier: "coach.profile.help", timeoutMs: 3000, pollIntervalMs: 100
    });
    tapResponseMs = Date.now() - tapStart;
    if (!response.structuredContent?.data?.waitMatch?.matches?.length || tapResponseMs > 3000) {
      assertion.exit_code = 1;
    }
  }
  const result = {
    name, fixture, extraArgs, exitCode: assertion.exit_code, output: assertion.output.trim(), watchdogWallMs,
    targets: screen?.targets?.length, fixtureLoaded, tapResponseMs
  };
  await tools.apply_patch(`*** Begin Patch\n*** Add File: ${directory}/${name}.json\n+${JSON.stringify(result)}\n*** End Patch`);
  return result;
})
