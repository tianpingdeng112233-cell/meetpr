import Foundation
import Testing
import ZIPFoundation

@testable import CoachKit

// spec 043 hardening — WPS Office writes private relationship types (wps.cn/…) into
// the .rels parts. CoreXLSX's strict SchemaType enum throws on them, so a WPS file
// won't open at all. The sanitizer drops foreign Relationship elements, keeping only
// the standard openxmlformats ones CoreXLSX understands.

@Test func stripsWPSRelationshipButKeepsStandardOnes() {
  let rels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>\
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
    <Relationship Id="rId1" \
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" \
    Target="worksheets/sheet1.xml"/>\
    <Relationship Id="rId9" \
    Type="http://www.wps.cn/officeDocument/2023/relationships/woinfos" Target="woinfos.xml"/>\
    </Relationships>
    """

  let cleaned = WPSWorkbookSanitizer.stripForeignRelationships(fromRels: rels)

  #expect(cleaned.contains("worksheets/sheet1.xml"))  // standard relationship kept
  #expect(!cleaned.contains("wps.cn"))  // foreign type removed
  #expect(!cleaned.contains("woinfos"))
}

@Test func keepsExactCoreXLSXSupportedTypesDropsEverythingElse() {
  // CoreXLSX's SchemaType matches the FULL Type string, not a namespace prefix. A
  // microsoft `person` type is supported; a microsoft `threadedComment` is not and
  // still throws — so it must be dropped despite the shared namespace.
  let rels = """
    <Relationships>\
    <Relationship Id="r1" \
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" \
    Target="s1.xml"/>\
    <Relationship Id="r2" \
    Type="http://schemas.microsoft.com/office/2017/10/relationships/person" Target="p.xml"/>\
    <Relationship Id="r3" \
    Type="http://schemas.microsoft.com/office/2017/10/relationships/threadedComment" \
    Target="tc.xml"/>\
    <Relationship Id="r4" \
    Type="http://www.wps.cn/officeDocument/2023/relationships/woinfos" Target="woinfos.xml"/>\
    </Relationships>
    """
  let cleaned = WPSWorkbookSanitizer.stripForeignRelationships(fromRels: rels)
  #expect(cleaned.contains("s1.xml"))  // worksheet — exact supported, keep
  #expect(cleaned.contains("p.xml"))  // person — exact supported, keep
  #expect(!cleaned.contains("tc.xml"))  // threadedComment — microsoft but NOT in enum, drop
  #expect(!cleaned.contains("woinfos"))  // WPS — drop
}

@Test func leavesStandardOnlyRelsUnchanged() {
  let rels = """
    <Relationships>\
    <Relationship Id="rId1" \
    Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" \
    Target="xl/workbook.xml"/>\
    </Relationships>
    """
  #expect(WPSWorkbookSanitizer.stripForeignRelationships(fromRels: rels) == rels)
}

// MARK: - zip orchestration

private func makeZip(_ entries: [(path: String, data: Data)]) throws -> URL {
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathExtension("xlsx")
  let archive = try Archive(url: url, accessMode: .create)
  for entry in entries {
    try archive.addEntry(with: entry.path, type: .file, uncompressedSize: Int64(entry.data.count)) {
      position, size in
      let start = Int(position)
      return entry.data.subdata(in: start..<min(start + size, entry.data.count))
    }
  }
  return url
}

private func read(_ path: String, from url: URL) throws -> Data {
  let archive = try Archive(url: url, accessMode: .read)
  let entry = try #require(archive[path])
  var data = Data()
  _ = try archive.extract(entry) { data.append($0) }
  return data
}

private let wpsRels = Data(
  """
  <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
  <Relationship Id="rId1" \
  Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" \
  Target="xl/workbook.xml"/>\
  <Relationship Id="rId9" \
  Type="http://www.wps.cn/officeDocument/2023/relationships/woinfos" Target="xl/woinfos.xml"/>\
  </Relationships>
  """.utf8)

@Test func sanitizedWorkbookStripsWPSRelsAndPreservesOtherEntries() throws {
  let payload = Data("<workbook/>".utf8)
  let input = try makeZip([("_rels/.rels", wpsRels), ("xl/workbook.xml", payload)])

  let out = try #require(WPSWorkbookSanitizer.sanitizedWorkbookURL(for: input))

  let cleanedRels = try String(decoding: read("_rels/.rels", from: out), as: UTF8.self)
  #expect(!cleanedRels.contains("wps.cn"))
  #expect(cleanedRels.contains("xl/workbook.xml"))  // standard relationship survived
  #expect(try read("xl/workbook.xml", from: out) == payload)  // other parts byte-identical
}

@Test func sanitizedWorkbookReturnsNilWhenNothingForeign() throws {
  let standardRels = Data(
    #"<Relationships><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>"#
      .utf8)
  let input = try makeZip([("_rels/.rels", standardRels)])
  #expect(WPSWorkbookSanitizer.sanitizedWorkbookURL(for: input) == nil)
}
