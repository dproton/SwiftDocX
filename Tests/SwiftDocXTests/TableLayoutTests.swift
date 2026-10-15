import XCTest
@testable import SwiftDocX

/// Table width, fixed layout and cell margins, and table and cell properties in the order the OOXML schema requires.
final class TableLayoutTests: XCTestCase {

    func testATableWithoutWidthOrLayoutKeepsUpstreamsAutoTable() {
        let xml = DocumentXMLBuilder().buildTableXML(Table(rows: 1, columns: 1))

        XCTAssertTrue(xml.hasPrefix(
            "<w:tbl><w:tblPr><w:tblStyle w:val=\"TableGrid\"/><w:tblW w:w=\"0\" w:type=\"auto\"/><w:tblBorders>"
        ), xml)
        XCTAssertFalse(xml.contains("w:tblLayout"), xml)
        XCTAssertFalse(xml.contains("w:tblCellMar"), xml)
    }

    func testAFixedTableHasItsWidthLayoutAndCellMarginsInSchemaOrder() {
        let table = Table(rows: 1, columns: 2)
        table.width = 487.3
        table.columnWidths = [108, 379.3]
        table.alignment = .center
        table.borders = .all(.none)
        table.isFixedLayout = true
        table.cellMargins = TableCellMargins(top: 5, left: 0, bottom: 5, right: 0)

        let xml = DocumentXMLBuilder().buildTableXML(table)

        XCTAssertTrue(xml.hasPrefix(
            "<w:tbl><w:tblPr><w:tblStyle w:val=\"TableGrid\"/><w:tblW w:w=\"9746\" w:type=\"dxa\"/>"
                + "<w:jc w:val=\"center\"/><w:tblBorders>"
        ), xml)
        XCTAssertTrue(xml.contains(
            "</w:tblBorders><w:tblLayout w:type=\"fixed\"/><w:tblCellMar><w:top w:w=\"100\" w:type=\"dxa\"/>"
                + "<w:left w:w=\"0\" w:type=\"dxa\"/><w:bottom w:w=\"100\" w:type=\"dxa\"/><w:right w:w=\"0\" w:type=\"dxa\"/>"
                + "</w:tblCellMar></w:tblPr>"
        ), xml)
        // Rounded to the nearest twip: 379.3 pt is 7586, which upstream's truncation made 7585.
        XCTAssertTrue(xml.contains("<w:tblGrid><w:gridCol w:w=\"2160\"/><w:gridCol w:w=\"7586\"/></w:tblGrid>"), xml)
    }

    func testEveryCellMarginCanBeTheSame() {
        XCTAssertEqual(TableCellMargins.all(5), TableCellMargins(top: 5, left: 5, bottom: 5, right: 5))
        XCTAssertEqual(TableCellMargins.zero, TableCellMargins.all(0))
    }

    func testCellPropertiesFollowTheSchemaOrder() throws {
        let table = Table(rows: 1, columns: 2)
        let cell = try XCTUnwrap(table.cell(at: 0, column: 0))
        cell.width = 100
        cell.columnSpan = 2
        cell.borders = TableBorders(top: .single)
        cell.backgroundColor = Color(red: 0xD9, green: 0xD9, blue: 0xD9)
        cell.verticalAlignment = .center

        let xml = DocumentXMLBuilder().buildTableXML(table)

        XCTAssertTrue(xml.contains(
            "<w:tcPr><w:tcW w:w=\"2000\" w:type=\"dxa\"/><w:gridSpan w:val=\"2\"/>"
                + "<w:tcBorders><w:top w:val=\"single\" w:sz=\"4\" w:space=\"0\" w:color=\"auto\"/></w:tcBorders>"
                + "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"D9D9D9\"/><w:vAlign w:val=\"center\"/></w:tcPr>"
        ), xml)
    }
}
