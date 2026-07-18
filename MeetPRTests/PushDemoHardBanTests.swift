// MARK: - Demo hard-ban structural guard (runs in every configuration)
//
// The Demo ban is a compile-time property (#if !DEMO_MODE gating + no push
// entitlements), so no runtime assertion can catch its accidental removal.
// These tests read the sources and project file from disk via #filePath and
// fail if the structure that enforces the ban is ever weakened.

import Foundation
import Testing

private let repoRoot = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent()
  .deletingLastPathComponent()

@Test func demoBuildConfigurationsCarryNoPushEntitlements() throws {
  let pbxproj = try String(
    contentsOf: repoRoot.appendingPathComponent("MeetPR.xcodeproj/project.pbxproj"),
    encoding: .utf8
  )
  let demoBlocks = buildConfigurationBlocks(named: ["Demo", "DemoStudent"], in: pbxproj)

  // Project-level + app-target + tests-target for each of the two demo names.
  #expect(demoBlocks.count == 6)
  for block in demoBlocks {
    #expect(
      !block.body.contains("CODE_SIGN_ENTITLEMENTS"),
      "\(block.name) must not reference push entitlements"
    )
    #expect(
      !block.body.contains("APS_ENVIRONMENT"),
      "\(block.name) must not set aps-environment"
    )
  }

  // Per-target precision: the app target is the block carrying the app bundle
  // id. Each demo name must have exactly one such block, compiled DEMO_MODE.
  let appMarker = "PRODUCT_BUNDLE_IDENTIFIER = com.meetpr.app;"
  for name in ["Demo", "DemoStudent"] {
    let appBlocks = demoBlocks.filter { $0.name == name && $0.body.contains(appMarker) }
    #expect(appBlocks.count == 1, "expected exactly one \(name) app-target block")
    #expect(
      appBlocks.allSatisfy { $0.body.contains("DEMO_MODE") },
      "\(name) app target must compile with DEMO_MODE"
    )
  }

  // Real builds: Debug signs the entitlements with the development APS
  // environment, Release with production — each asserted on its own block so
  // a single-configuration regression cannot hide behind the other.
  let realBlocks = buildConfigurationBlocks(named: ["Debug", "Release"], in: pbxproj)
  let appDebug = realBlocks.filter { $0.name == "Debug" && $0.body.contains(appMarker) }
  let appRelease = realBlocks.filter { $0.name == "Release" && $0.body.contains(appMarker) }
  #expect(appDebug.count == 1)
  #expect(appRelease.count == 1)
  let entitlements = "CODE_SIGN_ENTITLEMENTS = MeetPR/MeetPR.entitlements;"
  #expect(appDebug.allSatisfy { $0.body.contains(entitlements) })
  #expect(appDebug.allSatisfy { $0.body.contains("APS_ENVIRONMENT = development;") })
  #expect(appRelease.allSatisfy { $0.body.contains(entitlements) })
  #expect(appRelease.allSatisfy { $0.body.contains("APS_ENVIRONMENT = production;") })
}

@Test func pushPipelineSourcesAreCompileTimeGatedOutOfDemo() throws {
  let pushDir = repoRoot.appendingPathComponent("MeetPR/Sources/Push")
  let files = try FileManager.default.contentsOfDirectory(atPath: pushDir.path)
    .filter { $0.hasSuffix(".swift") }
    .sorted()

  #expect(!files.isEmpty)
  for file in files {
    let source = try String(
      contentsOf: pushDir.appendingPathComponent(file), encoding: .utf8)
    let firstCodeLine =
      source
      .split(separator: "\n", omittingEmptySubsequences: true)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .first { !$0.isEmpty && !$0.hasPrefix("//") }
    #expect(
      firstCodeLine == "#if !DEMO_MODE",
      "\(file) must open with #if !DEMO_MODE so Demo builds contain no push symbols"
    )
  }
}

private struct BuildConfigurationBlock {
  let name: String
  let body: String
}

private func buildConfigurationBlocks(
  named names: Set<String>, in pbxproj: String
) -> [BuildConfigurationBlock] {
  var blocks: [BuildConfigurationBlock] = []
  let lines = pbxproj.components(separatedBy: "\n")
  var index = 0
  while index < lines.count {
    let line = lines[index]
    if let name = names.first(where: { line.hasSuffix("/* \($0) */ = {") }) {
      var depth = 0
      var body: [String] = []
      var cursor = index
      repeat {
        let current = lines[cursor]
        depth += current.filter { $0 == "{" }.count
        depth -= current.filter { $0 == "}" }.count
        body.append(current)
        cursor += 1
      } while depth > 0 && cursor < lines.count
      let joined = body.joined(separator: "\n")
      if joined.contains("isa = XCBuildConfiguration;") {
        blocks.append(BuildConfigurationBlock(name: name, body: joined))
      }
      index = cursor
    } else {
      index += 1
    }
  }
  return blocks
}
