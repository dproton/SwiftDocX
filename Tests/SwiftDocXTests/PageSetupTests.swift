import XCTest
@testable import SwiftDocX

/// The paper size, orientation and margins of the document's section.
final class PageSetupTests: XCTestCase {

    private let upstreamLetter = "<w:pgSz w:w=\"12240\" w:h=\"15840\"/>"
        + "<w:pgMar w:top=\"1440\" w:right=\"1440\" w:bottom=\"1440\" w:left=\"1440\" w:header=\"720\" w:footer=\"720\" w:gutter=\"0\"/>"

    /// A document that never sets its page keeps the Letter page upstream SwiftDocX writes.
    func testTheDefaultWritesUpstreamsLetterPage() {
        XCTAssertEqual(Document().pageSetup, .letter)
        XCTAssertEqual(PageSetup.letter.sectionPropertiesXML(), upstreamLetter)
        let xml = DocumentXMLBuilder().buildDocumentXML(elements: [])
        XCTAssertTrue(xml.contains("<w:sectPr>" + upstreamLetter + "</w:sectPr>"), xml)
    }

    func testA4PortraitWithItsOwnMargins() {
        let margins = PageSetup.Margins(top: 54, right: 54, bottom: 54, left: 54, header: 36, footer: 24)
        let setup = PageSetup(paperSize: .a4, margins: margins)

        XCTAssertEqual(
            setup.sectionPropertiesXML(),
            "<w:pgSz w:w=\"11906\" w:h=\"16838\"/>"
                + "<w:pgMar w:top=\"1080\" w:right=\"1080\" w:bottom=\"1080\" w:left=\"1080\" w:header=\"720\" w:footer=\"480\" w:gutter=\"0\"/>"
        )
    }

    func testLandscapeSwapsTheSidesAndSaysSo() {
        let setup = PageSetup(paperSize: .a4, orientation: .landscape)

        XCTAssertTrue(setup.sectionPropertiesXML().hasPrefix("<w:pgSz w:w=\"16838\" w:h=\"11906\" w:orient=\"landscape\"/>"))
    }

    func testAWrittenDocumentCarriesItsPageSetup() throws {
        let document = Document()
        document.pageSetup = PageSetup(paperSize: .a4)
        document.addParagraph("Hello")
        document.setFooterWithPageNumbersAndTotal()

        let xml = try writtenDocumentXML(document)

        XCTAssertTrue(xml.contains("<w:footerReference w:type=\"default\""), xml)
        XCTAssertTrue(xml.contains("<w:pgSz w:w=\"11906\" w:h=\"16838\"/>"), xml)
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
