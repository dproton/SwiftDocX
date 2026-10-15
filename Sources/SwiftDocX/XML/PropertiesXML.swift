import Foundation

// The `w:pPr` and `w:rPr` elements both XML builders write, so body text, table cells, headers and footers agree.
// Children follow the order ECMA-376 Part 1 requires (CT_PPrBase, CT_RPr): Word refuses or repairs some files whose
// properties are out of order.

extension Paragraph {

    /// The paragraph's `w:pPr` element: pStyle, keepNext, keepLines, pageBreakBefore, numPr, spacing, ind, jc.
    /// Empty when the paragraph sets none of them.
    func propertiesXML() -> String {
        var xml = ""
        if let heading = headingLevel {
            xml += "<w:pStyle w:val=\"\(heading.styleId)\"/>"
        }
        if keepWithNext {
            xml += "<w:keepNext/>"
        }
        if keepLinesTogether {
            xml += "<w:keepLines/>"
        }
        if pageBreakBefore {
            xml += "<w:pageBreakBefore/>"
        }
        if let listType = listType {
            let numId = listType == .bullet ? 1 : 2
            xml += "<w:numPr><w:ilvl w:val=\"\(listLevel)\"/><w:numId w:val=\"\(numId)\"/></w:numPr>"
        }
        xml += spacingXML()
        xml += indentationXML()
        if let alignment = alignment {
            xml += "<w:jc w:val=\"\(alignment.rawValue)\"/>"
        }
        guard !xml.isEmpty else {
            return ""
        }
        return "<w:pPr>\(xml)</w:pPr>"
    }

    private func spacingXML() -> String {
        var attributes = ""
        if let before = spacing.before {
            attributes += " w:before=\"\(before.twips)\""
        }
        if let after = spacing.after {
            attributes += " w:after=\"\(after.twips)\""
        }
        if let lineSpacing = spacing.lineSpacing {
            attributes += " w:line=\"\(Int((lineSpacing * 240).rounded()))\" w:lineRule=\"auto\""
        }
        guard !attributes.isEmpty else {
            return ""
        }
        return "<w:spacing\(attributes)/>"
    }

    private func indentationXML() -> String {
        var attributes = ""
        if let left = indentation.left {
            attributes += " w:left=\"\(left.twips)\""
        }
        if let right = indentation.right {
            attributes += " w:right=\"\(right.twips)\""
        }
        if let firstLine = indentation.firstLine {
            if firstLine >= 0 {
                attributes += " w:firstLine=\"\(firstLine.twips)\""
            } else {
                attributes += " w:hanging=\"\((-firstLine).twips)\""
            }
        }
        guard !attributes.isEmpty else {
            return ""
        }
        return "<w:ind\(attributes)/>"
    }
}

extension TextFormatting {

    /// The run's `w:rPr` element: rFonts, b, i, caps, smallCaps, strike, color, sz, szCs, highlight, u, vertAlign.
    /// Empty when nothing is set.
    func propertiesXML() -> String {
        var xml = ""
        if let font = font {
            let name = XMLEscaping.attribute(font.name)
            xml += "<w:rFonts w:ascii=\"\(name)\" w:hAnsi=\"\(name)\" w:cs=\"\(name)\"/>"
        }
        if bold {
            xml += "<w:b/>"
        }
        if italic {
            xml += "<w:i/>"
        }
        if allCaps {
            xml += "<w:caps/>"
        }
        if smallCaps {
            xml += "<w:smallCaps/>"
        }
        if strikethrough {
            xml += "<w:strike/>"
        }
        if let color = color {
            xml += "<w:color w:val=\"\(color.hexString)\"/>"
        }
        if let fontSize = fontSize {
            let halfPoints = Int((fontSize * 2).rounded())
            xml += "<w:sz w:val=\"\(halfPoints)\"/><w:szCs w:val=\"\(halfPoints)\"/>"
        }
        if let highlight = highlight {
            xml += "<w:highlight w:val=\"\(highlight.rawValue)\"/>"
        }
        if let underline = underline {
            xml += "<w:u w:val=\"\(underline.rawValue)\"/>"
        }
        if superscript {
            xml += "<w:vertAlign w:val=\"superscript\"/>"
        } else if subscriptText {
            xml += "<w:vertAlign w:val=\"subscript\"/>"
        }
        guard !xml.isEmpty else {
            return ""
        }
        return "<w:rPr>\(xml)</w:rPr>"
    }
}

/// Escaping for text the builders put inside XML attributes.
enum XMLEscaping {
    static func attribute(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
