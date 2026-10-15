import XCTest
@testable import SwiftDocX

/// Paragraph, run and row properties: the keep-together options, and children in the order the OOXML schema requires.
final class ParagraphPropertiesTests: XCTestCase {

    func testAPlainParagraphAndPlainTextHaveNoProperties() {
        XCTAssertEqual(Paragraph("Kate").propertiesXML(), "")
        XCTAssertEqual(TextFormatting.none.propertiesXML(), "")
    }

    func testKeepOptionsFollowTheStyleAndPrecedeAPageBreak() {
        let paragraph = Paragraph("A")
        paragraph.headingLevel = .heading2
        paragraph.keepWithNext = true
        paragraph.keepLinesTogether = true
        paragraph.pageBreakBefore = true

        XCTAssertEqual(
            paragraph.propertiesXML(),
            "<w:pPr><w:pStyle w:val=\"Heading2\"/><w:keepNext/><w:keepLines/><w:pageBreakBefore/></w:pPr>"
        )
    }

    func testSpacingAndIndentationComeBeforeAlignment() {
        let paragraph = Paragraph("A")
        paragraph.alignment = .center
        paragraph.spacing = ParagraphSpacing(before: 3, after: 4.5, lineSpacing: 1.2)
        paragraph.indentation = ParagraphIndentation(left: 10, firstLine: -10)

        XCTAssertEqual(
            paragraph.propertiesXML(),
            "<w:pPr><w:spacing w:before=\"60\" w:after=\"90\" w:line=\"288\" w:lineRule=\"auto\"/>"
                + "<w:ind w:left=\"200\" w:hanging=\"200\"/><w:jc w:val=\"center\"/></w:pPr>"
        )
    }

    func testRunPropertiesFollowTheSchemaOrder() {
        let formatting = TextFormatting(
            bold: true,
            italic: true,
            underline: .single,
            strikethrough: true,
            font: .arial,
            color: Color(red: 0x0F, green: 0x5F, blue: 0x5C),
            fontSize: 10.5,
            allCaps: true,
            highlight: .yellow
        )

        XCTAssertEqual(
            formatting.propertiesXML(),
            "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/><w:b/><w:i/><w:caps/><w:strike/>"
                + "<w:color w:val=\"0F5F5C\"/><w:sz w:val=\"21\"/><w:szCs w:val=\"21\"/>"
                + "<w:highlight w:val=\"yellow\"/><w:u w:val=\"single\"/></w:rPr>"
        )
    }

    func testARowThatCantSplitSaysSo() {
        let table = Table(rows: 1, columns: 1)
        table.rows[0].cantSplit = true
        table.rows[0].isHeader = true

        let xml = DocumentXMLBuilder().buildTableXML(table)

        XCTAssertTrue(xml.contains("<w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>"), xml)
    }

    /// Word shows a field's result in the result run's own font, so every run of a page-number field carries the
    /// formatting: "Page ", the PAGE field's five runs, " of " and the NUMPAGES field's five runs.
    func testEveryRunOfAPageNumberFieldCarriesTheFormatting() {
        let footer = Footer()
        footer.addPageNumberWithTotal(formatting: TextFormatting(font: .arial, fontSize: 9), alignment: .center)

        let xml = DocumentXMLBuilder().buildFooterXML(footer)

        let properties = "<w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/><w:sz w:val=\"18\"/><w:szCs w:val=\"18\"/></w:rPr>"
        XCTAssertEqual(xml.components(separatedBy: "<w:r>" + properties).count - 1, 12, xml)
    }

    /// Body text goes through `DocumentWriter`, table cells through `DocumentXMLBuilder`: both write the same.
    func testBodyTextAndTableCellsWriteTheSameProperties() throws {
        let formatting = TextFormatting(bold: true, font: .arial, fontSize: 12)
        let document = Document()
        document.addParagraph("Kate Bell", formatting: formatting).keepWithNext = true
        let table = Table(rows: 1, columns: 1)
        let cell = try XCTUnwrap(table.cell(at: 0, column: 0))
        cell.paragraphs = []
        cell.addParagraph("Kate Bell", formatting: formatting).keepWithNext = true
        document.addTable(table)

        let xml = try writtenDocumentXML(document)

        let expected = "<w:p><w:pPr><w:keepNext/></w:pPr><w:r><w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/>"
            + "<w:b/><w:sz w:val=\"24\"/><w:szCs w:val=\"24\"/></w:rPr><w:t>Kate Bell</w:t></w:r></w:p>"
        XCTAssertEqual(xml.components(separatedBy: expected).count - 1, 2, xml)
    }

    private func writtenDocumentXML(_ document: Document) throws -> String {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".docx")
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        try document.write(to: url)
        return try XCTUnwrap(String(data: ZIPReader().readEntry(at: url, entryPath: "word/document.xml"), encoding: .utf8))
    }
}
