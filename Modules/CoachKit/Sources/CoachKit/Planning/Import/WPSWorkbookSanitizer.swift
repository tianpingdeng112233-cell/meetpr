import Foundation
import ZIPFoundation

// Makes WPS Office workbooks readable by CoreXLSX (spec 043 hardening). WPS injects
// private relationship types (`http://www.wps.cn/…`) that CoreXLSX's strict
// SchemaType enum rejects with `dataCorrupted`, so the file cannot be opened at all.
// Stripping the foreign Relationship elements (leaving only standard openxmlformats
// ones) lets the otherwise-valid workbook parse. Orphaned target parts (woinfos.xml)
// are harmless once unreferenced.

enum WPSWorkbookSanitizer {
  /// The EXACT relationship `Type` values CoreXLSX's `SchemaType` enum decodes. It
  /// matches the full string (not a namespace prefix) and throws `dataCorrupted` on
  /// anything else — so a `schemas.microsoft.com/.../threadedComment` breaks it just
  /// as a `wps.cn/…` does. Only these survive; every other relationship is dropped
  /// (none are needed to read cells). Mirror of CoreXLSX `Relationships.SchemaType`
  /// (pinned `0.14.2`); revisit if that pin moves.
  private static let supportedRelationshipTypes: Set<String> = [
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/calcChain",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties",
    "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/metadata/core-properties",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/connections",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/chartsheet",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/pivotCacheDefinition",
    "http://schemas.openxmlformats.org/package/2006/relationships/metadata/thumbnail",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/custom-properties",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/customXml",
    "http://schemas.microsoft.com/office/2017/10/relationships/person",
    "http://schemas.microsoft.com/office/2011/relationships/webextensiontaskpanes",
    "http://customschemas.google.com/relationships/workbookmetadata",
    "http://purl.oclc.org/ooxml/officeDocument/relationships/extendedProperties",
  ]

  /// Extracts the `Type="…"` value from a `<Relationship .../>` element, or nil.
  private static func relationshipType(in element: String) -> String? {
    guard
      let regex = try? NSRegularExpression(pattern: "Type=\"([^\"]*)\""),
      let match = regex.firstMatch(
        in: element, range: NSRange(element.startIndex..., in: element)),
      let range = Range(match.range(at: 1), in: element)
    else { return nil }
    return String(element[range])
  }

  /// If `fileURL` is a WPS workbook (its `.rels` carry foreign relationship types),
  /// writes a sanitized copy to a temp file and returns its URL. Returns nil when no
  /// `.rels` needed changing — the original opens fine, so callers use it as-is.
  static func sanitizedWorkbookURL(for fileURL: URL) -> URL? {
    guard let source = try? Archive(url: fileURL, accessMode: .read) else { return nil }

    var entries: [(path: String, data: Data)] = []
    var changed = false
    for entry in source where entry.type == .file {  // xlsx parts are all files
      var data = Data()
      guard (try? source.extract(entry) { data.append($0) }) != nil else { return nil }
      if entry.path.hasSuffix(".rels"), let xml = String(data: data, encoding: .utf8) {
        let cleaned = stripForeignRelationships(fromRels: xml)
        if cleaned != xml {
          data = Data(cleaned.utf8)
          changed = true
        }
      }
      entries.append((entry.path, data))
    }
    guard changed else { return nil }  // not a WPS workbook — original opens fine

    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("xlsx")
    guard let output = try? Archive(url: destination, accessMode: .create) else { return nil }
    for entry in entries {
      do {
        try output.addEntry(
          with: entry.path, type: .file, uncompressedSize: Int64(entry.data.count)
        ) { position, size in
          let start = Int(position)
          return entry.data.subdata(in: start..<min(start + size, entry.data.count))
        }
      } catch {
        try? FileManager.default.removeItem(at: destination)  // no partial temp left behind
        return nil
      }
    }
    return destination
  }

  /// Drops `<Relationship>` elements whose `Type` is not a standard openxmlformats
  /// relationship, returning the rewritten `.rels` XML. Standard-only input is
  /// returned byte-for-byte unchanged.
  static func stripForeignRelationships(fromRels relsXML: String) -> String {
    guard relsXML.contains("<Relationship") else { return relsXML }
    guard let regex = try? NSRegularExpression(pattern: "<Relationship\\b[^>]*/>") else {
      return relsXML
    }
    let source = relsXML as NSString
    let matches = regex.matches(in: relsXML, range: NSRange(location: 0, length: source.length))
    guard !matches.isEmpty else { return relsXML }

    var result = ""
    var cursor = 0
    for match in matches {
      result += source.substring(
        with: NSRange(location: cursor, length: match.range.location - cursor))
      let element = source.substring(with: match.range)
      if let type = relationshipType(in: element), supportedRelationshipTypes.contains(type) {
        result += element  // CoreXLSX-supported relationship — keep verbatim
      }  // unsupported (WPS / drawings / comments…) — drop
      cursor = match.range.location + match.range.length
    }
    result += source.substring(from: cursor)
    return result
  }
}
