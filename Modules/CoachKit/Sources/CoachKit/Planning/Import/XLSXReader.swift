import CoreXLSX
import Foundation

// Thin read-only wrapper over CoreXLSX (spec 043 §A): resolves cells into the
// internal `CellGrid` seam so the geometry/parser are testable without a binary
// fixture. The file is read inside a security-scoped resource scope and never
// leaves the device.

enum XLSXReaderError: Error, Equatable, Sendable {
  case cannotOpen
  case noWorksheet
  case sheetNotFound(String)
}

struct XLSXReader {
  let fileURL: URL

  /// Names of the non-empty worksheets, in workbook order.
  func sheetNames() throws -> [String] {
    try withFile { file in
      var names: [String] = []
      for workbook in try file.parseWorkbooks() {
        for (name, _) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
          if let name { names.append(name) }
        }
      }
      return names
    }
  }

  /// Cells of a named sheet.
  func cells(inSheetNamed name: String) throws -> CellGrid {
    try withFile { file in
      let path = try worksheetPath(named: name, in: file)
      return try grid(at: path, file: file)
    }
  }

  /// Cells of the first (or only) worksheet — used when there is a single plan page.
  func firstSheetGrid() throws -> CellGrid {
    try withFile { file in
      guard let path = try file.parseWorksheetPaths().first else {
        throw XLSXReaderError.noWorksheet
      }
      return try grid(at: path, file: file)
    }
  }

  // MARK: - security-scoped access

  private func withFile<T>(_ body: (XLSXFile) throws -> T) throws -> T {
    let scoped = fileURL.startAccessingSecurityScopedResource()
    defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
    guard let file = XLSXFile(filepath: fileURL.path) else {
      throw XLSXReaderError.cannotOpen
    }
    return try body(file)
  }

  private func worksheetPath(named name: String, in file: XLSXFile) throws -> String {
    for workbook in try file.parseWorkbooks() {
      for (sheetName, path) in try file.parseWorksheetPathsAndNames(workbook: workbook)
      where sheetName == name {
        return path
      }
    }
    throw XLSXReaderError.sheetNotFound(name)
  }

  private func grid(at path: String, file: XLSXFile) throws -> CellGrid {
    let worksheet = try file.parseWorksheet(at: path)
    let sharedStrings = try? file.parseSharedStrings()
    var triples: [(row: Int, col: Int, value: CellValue)] = []
    for row in worksheet.data?.rows ?? [] {
      let rowIndex = Int(row.reference)
      for cell in row.cells {
        let colIndex = Self.columnIndex(cell.reference.column.value)
        guard colIndex > 0, let value = Self.cellValue(cell, sharedStrings: sharedStrings) else {
          continue
        }
        triples.append((row: rowIndex, col: colIndex, value: value))
      }
    }
    return CellGrid(triples)
  }

  private static func cellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> CellValue? {
    if let sharedStrings, let resolved = cell.stringValue(sharedStrings) {
      return nonEmptyText(resolved)
    }
    if let inline = cell.inlineString?.text {
      return nonEmptyText(inline)
    }
    if let raw = cell.value {
      if let number = Double(raw) { return .number(number) }
      return nonEmptyText(raw)
    }
    return nil
  }

  private static func nonEmptyText(_ value: String) -> CellValue? {
    value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .text(value)
  }

  /// `"A"` → 1, `"AE"` → 31. Ignores non-letter characters defensively.
  static func columnIndex(_ letters: String) -> Int {
    var result = 0
    for scalar in letters.uppercased().unicodeScalars where ("A"..."Z").contains(Character(scalar))
    {
      result = result * 26 + (Int(scalar.value) - 64)
    }
    return result
  }
}
