import Foundation

/// The paper size, orientation and margins of a document's single section.
public struct PageSetup: Equatable, Sendable {

    /// A sheet's portrait width and height, in points.
    public struct PaperSize: Equatable, Sendable {
        public var width: Double
        public var height: Double

        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }

        /// US Letter, 8.5 × 11 in.
        public static let letter = PaperSize(width: 612, height: 792)

        /// ISO A4, 210 × 297 mm, as Word stores it (11906 × 16838 twips).
        public static let a4 = PaperSize(width: 595.3, height: 841.9)
    }

    /// Which way the sheet is turned.
    public enum Orientation: Sendable {
        case portrait
        case landscape
    }

    /// Page margins, in points. `header` and `footer` are the distances from the sheet's edge to the header and to
    /// the footer.
    public struct Margins: Equatable, Sendable {
        public var top: Double
        public var right: Double
        public var bottom: Double
        public var left: Double
        public var header: Double
        public var footer: Double

        public init(
            top: Double,
            right: Double,
            bottom: Double,
            left: Double,
            header: Double,
            footer: Double
        ) {
            self.top = top
            self.right = right
            self.bottom = bottom
            self.left = left
            self.header = header
            self.footer = footer
        }

        /// 1 in on every side; header and footer 0.5 in from the edge.
        public static let standard = Margins(top: 72, right: 72, bottom: 72, left: 72, header: 36, footer: 36)
    }

    public var paperSize: PaperSize
    public var orientation: Orientation
    public var margins: Margins

    public init(paperSize: PaperSize = .letter, orientation: Orientation = .portrait, margins: Margins = .standard) {
        self.paperSize = paperSize
        self.orientation = orientation
        self.margins = margins
    }

    /// Letter, portrait, 1 in margins: the page SwiftDocX wrote before page setup existed.
    public static let letter = PageSetup()

    /// The section's `w:pgSz` and `w:pgMar` elements.
    func sectionPropertiesXML() -> String {
        let isLandscape = orientation == .landscape
        let width = isLandscape ? paperSize.height : paperSize.width
        let height = isLandscape ? paperSize.width : paperSize.height
        var xml = "<w:pgSz w:w=\"\(width.twips)\" w:h=\"\(height.twips)\""
        if isLandscape {
            xml += " w:orient=\"landscape\""
        }
        xml += "/>"
        xml += "<w:pgMar w:top=\"\(margins.top.twips)\" w:right=\"\(margins.right.twips)\""
        xml += " w:bottom=\"\(margins.bottom.twips)\" w:left=\"\(margins.left.twips)\""
        xml += " w:header=\"\(margins.header.twips)\" w:footer=\"\(margins.footer.twips)\" w:gutter=\"0\"/>"
        return xml
    }
}

extension Double {
    /// These points in twentieths of a point (twips), the unit of Word's page, table, spacing and indent elements.
    var twips: Int {
        return Int((self * 20).rounded())
    }
}
