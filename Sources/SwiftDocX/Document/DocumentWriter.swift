import Foundation

/// Error types for document writing operations
public enum DocumentWriterError: Error, LocalizedError {
    case writeFailed(String)
    case invalidDestination(String)

    public var errorDescription: String? {
        switch self {
        case .writeFailed(let detail):
            return "Failed to write document: \(detail)"
        case .invalidDestination(let path):
            return "Invalid destination path: \(path)"
        }
    }
}

/// Writes Word documents to .docx files
public class DocumentWriter {
    private let xmlBuilder: DocumentXMLBuilder
    private let zipWriter: ZIPWriter
    private var relationshipId: Int = 3  // Start after styles and settings

    public init() {
        self.xmlBuilder = DocumentXMLBuilder()
        self.zipWriter = ZIPWriter()
    }

    /// Writes a full document to a .docx file
    public func write(document: Document, to url: URL) throws {
        var contents: [String: Data] = [:]
        var relationships: [(id: String, type: String, target: String)] = []
        var contentTypeOverrides: [(partName: String, contentType: String)] = []

        // Check features needed
        let hasLists = document.elements.contains { element in
            if case .paragraph(let para) = element {
                return para.listType != nil
            }
            return false
        }

        // rId1 = styles.xml, rId2 = settings.xml, rId3 = numbering.xml (if lists exist)
        // Start additional relationships after these
        relationshipId = hasLists ? 4 : 3

        // Collect all images and assign relationship IDs
        var images: [DocImage] = []
        for element in document.elements {
            if case .paragraph(let para) = element {
                for run in para.runs {
                    if let image = run.image {
                        let relId = "rId\(relationshipId)"
                        image.relationshipId = relId
                        relationships.append((
                            id: relId,
                            type: XMLNamespaces.relationshipImage,
                            target: "media/image\(images.count + 1).\(image.fileExtension)"
                        ))
                        contentTypeOverrides.append((
                            partName: "/word/media/image\(images.count + 1).\(image.fileExtension)",
                            contentType: image.contentType
                        ))
                        images.append(image)
                        relationshipId += 1
                    }
                    if let hyperlink = run.hyperlink {
                        let relId = "rId\(relationshipId)"
                        hyperlink.relationshipId = relId
                        relationships.append((
                            id: relId,
                            type: XMLNamespaces.relationshipHyperlink,
                            target: hyperlink.url
                        ))
                        relationshipId += 1
                    }
                }
            }
        }

        // Handle header
        var headerRelId: String? = nil
        if let header = document.header {
            headerRelId = "rId\(relationshipId)"
            header.relationshipId = headerRelId
            relationships.append((
                id: headerRelId!,
                type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/header",
                target: "header1.xml"
            ))
            contentTypeOverrides.append((
                partName: "/word/header1.xml",
                contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"
            ))
            relationshipId += 1

            let headerXML = xmlBuilder.buildHeaderXML(header)
            guard let headerData = headerXML.data(using: .utf8) else {
                throw DocumentWriterError.writeFailed("Failed to encode header XML")
            }
            contents["word/header1.xml"] = headerData
        }

        // Handle footer
        var footerRelId: String? = nil
        if let footer = document.footer {
            footerRelId = "rId\(relationshipId)"
            footer.relationshipId = footerRelId
            relationships.append((
                id: footerRelId!,
                type: "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer",
                target: "footer1.xml"
            ))
            contentTypeOverrides.append((
                partName: "/word/footer1.xml",
                contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"
            ))
            relationshipId += 1

            let footerXML = xmlBuilder.buildFooterXML(footer)
            guard let footerData = footerXML.data(using: .utf8) else {
                throw DocumentWriterError.writeFailed("Failed to encode footer XML")
            }
            contents["word/footer1.xml"] = footerData
        }

        // Build document XML with header/footer references
        let documentXML = buildDocumentXMLWithHeaderFooter(
            elements: document.elements,
            headerRelId: headerRelId,
            footerRelId: footerRelId,
            pageSetup: document.pageSetup
        )

        // Build content types
        let contentTypesXML = buildContentTypesXML(
            hasNumbering: hasLists,
            additionalOverrides: contentTypeOverrides
        )

        // Build relationships
        let documentRelsXML = buildDocumentRelsXML(
            hasNumbering: hasLists,
            additionalRels: relationships
        )

        let rootRelsXML = xmlBuilder.buildRootRelsXML()
        let stylesXML = xmlBuilder.buildStylesXML()
        let settingsXML = xmlBuilder.buildSettingsXML()

        guard let documentData = documentXML.data(using: .utf8),
              let contentTypesData = contentTypesXML.data(using: .utf8),
              let rootRelsData = rootRelsXML.data(using: .utf8),
              let documentRelsData = documentRelsXML.data(using: .utf8),
              let stylesData = stylesXML.data(using: .utf8),
              let settingsData = settingsXML.data(using: .utf8) else {
            throw DocumentWriterError.writeFailed("Failed to encode XML content")
        }

        contents["[Content_Types].xml"] = contentTypesData
        contents["_rels/.rels"] = rootRelsData
        contents["word/document.xml"] = documentData
        contents["word/_rels/document.xml.rels"] = documentRelsData
        contents["word/styles.xml"] = stylesData
        contents["word/settings.xml"] = settingsData

        // Add numbering.xml if we have lists
        if hasLists {
            let numberingXML = xmlBuilder.buildNumberingXML()
            guard let numberingData = numberingXML.data(using: .utf8) else {
                throw DocumentWriterError.writeFailed("Failed to encode numbering XML")
            }
            contents["word/numbering.xml"] = numberingData
        }

        // Add images
        for (index, image) in images.enumerated() {
            contents["word/media/image\(index + 1).\(image.fileExtension)"] = image.data
        }

        // Write the docx file
        do {
            try zipWriter.createDocX(at: url, contents: contents)
        } catch {
            throw DocumentWriterError.writeFailed(error.localizedDescription)
        }
    }

    /// Writes document elements to a .docx file (legacy, no header/footer support)
    public func write(elements: [DocumentElement], to url: URL) throws {
        let doc = Document()
        for element in elements {
            switch element {
            case .paragraph(let para):
                doc.paragraphs.append(para)
                doc.elements.append(element)
            case .table(let table):
                doc.tables.append(table)
                doc.elements.append(element)
            }
        }
        try write(document: doc, to: url)
    }

    /// Legacy method - writes paragraphs to a .docx file
    public func write(paragraphs: [Paragraph], to url: URL) throws {
        let elements = paragraphs.map { DocumentElement.paragraph($0) }
        try write(elements: elements, to: url)
    }

    // MARK: - Private Helpers

    private func buildDocumentXMLWithHeaderFooter(
        elements: [DocumentElement],
        headerRelId: String?,
        footerRelId: String?,
        pageSetup: PageSetup
    ) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="\(XMLNamespaces.wordprocessingML)" xmlns:r="\(XMLNamespaces.relationships)">
        <w:body>
        """

        for element in elements {
            switch element {
            case .paragraph(let paragraph):
                xml += buildParagraphXML(paragraph)
            case .table(let table):
                xml += xmlBuilder.buildTableXML(table)
            }
        }

        // Section properties with header/footer references
        xml += "<w:sectPr>"
        if let headerRelId = headerRelId {
            xml += "<w:headerReference w:type=\"default\" r:id=\"\(headerRelId)\"/>"
        }
        if let footerRelId = footerRelId {
            xml += "<w:footerReference w:type=\"default\" r:id=\"\(footerRelId)\"/>"
        }
        xml += pageSetup.sectionPropertiesXML()
        xml += "</w:sectPr>"

        xml += """
        </w:body>
        </w:document>
        """

        return xml
    }

    private func buildParagraphXML(_ paragraph: Paragraph) -> String {
        var xml = "<w:p>"

        xml += paragraph.propertiesXML()

        // Runs
        for run in paragraph.runs {
            xml += buildRunXML(run)
        }

        xml += "</w:p>"
        return xml
    }

    private func buildRunXML(_ run: Run) -> String {
        var xml = ""

        // Handle hyperlinks
        if let hyperlink = run.hyperlink, let relId = hyperlink.relationshipId {
            var hyperlinkAttrs = "r:id=\"\(relId)\""
            if let tooltip = hyperlink.tooltip {
                hyperlinkAttrs += " w:tooltip=\"\(escapeXMLAttribute(tooltip))\""
            }
            xml += "<w:hyperlink \(hyperlinkAttrs)>"
        }

        xml += "<w:r>"

        // Every run of a page-number field repeats it, or Word shows the number in its default font.
        let runProperties = run.formatting.propertiesXML()
        xml += runProperties

        // Handle page number field
        if run.isPageNumberField {
            xml += "<w:fldChar w:fldCharType=\"begin\"/></w:r>"
            xml += "<w:r>\(runProperties)<w:instrText>PAGE</w:instrText></w:r>"
            xml += "<w:r>\(runProperties)<w:fldChar w:fldCharType=\"separate\"/></w:r>"
            xml += "<w:r>\(runProperties)<w:t>1</w:t></w:r>"
            xml += "<w:r>\(runProperties)<w:fldChar w:fldCharType=\"end\"/>"
        }
        // Handle total pages field
        else if run.isTotalPagesField {
            xml += "<w:fldChar w:fldCharType=\"begin\"/></w:r>"
            xml += "<w:r>\(runProperties)<w:instrText>NUMPAGES</w:instrText></w:r>"
            xml += "<w:r>\(runProperties)<w:fldChar w:fldCharType=\"separate\"/></w:r>"
            xml += "<w:r>\(runProperties)<w:t>1</w:t></w:r>"
            xml += "<w:r>\(runProperties)<w:fldChar w:fldCharType=\"end\"/>"
        }
        // Handle image
        else if let image = run.image, let relId = image.relationshipId {
            xml += buildImageDrawingXML(image, relationshipId: relId)
        }
        // Normal text
        else {
            let escapedText = escapeXML(run.text)
            let needsPreserveSpace = run.text.hasPrefix(" ") || run.text.hasSuffix(" ") || run.text.contains("  ")
            if needsPreserveSpace {
                xml += "<w:t xml:space=\"preserve\">\(escapedText)</w:t>"
            } else {
                xml += "<w:t>\(escapedText)</w:t>"
            }
        }

        xml += "</w:r>"

        // Close hyperlink
        if run.hyperlink != nil && run.hyperlink?.relationshipId != nil {
            xml += "</w:hyperlink>"
        }

        return xml
    }

    private func buildImageDrawingXML(_ image: DocImage, relationshipId: String) -> String {
        let widthEmu = Int((image.width ?? 200) * 914400 / 72)
        let heightEmu = Int((image.height ?? 200) * 914400 / 72)
        let altText = escapeXMLAttribute(image.altText ?? "Image")
        let title = escapeXMLAttribute(image.title ?? "")

        return """
        <w:drawing>
        <wp:inline distT="0" distB="0" distL="0" distR="0" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
        <wp:extent cx="\(widthEmu)" cy="\(heightEmu)"/>
        <wp:docPr id="1" name="Picture" descr="\(altText)" title="\(title)"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
        <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
        <pic:nvPicPr>
        <pic:cNvPr id="0" name="Picture" descr="\(altText)"/>
        <pic:cNvPicPr/>
        </pic:nvPicPr>
        <pic:blipFill>
        <a:blip r:embed="\(relationshipId)" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
        <a:stretch><a:fillRect/></a:stretch>
        </pic:blipFill>
        <pic:spPr>
        <a:xfrm><a:off x="0" y="0"/><a:ext cx="\(widthEmu)" cy="\(heightEmu)"/></a:xfrm>
        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
        </pic:spPr>
        </pic:pic>
        </a:graphicData>
        </a:graphic>
        </wp:inline>
        </w:drawing>
        """
    }

    private func buildContentTypesXML(hasNumbering: Bool, additionalOverrides: [(partName: String, contentType: String)]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="\(XMLNamespaces.contentTypes)">
        <Default Extension="rels" ContentType="\(XMLNamespaces.contentTypeRelationships)"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Default Extension="png" ContentType="image/png"/>
        <Default Extension="jpeg" ContentType="image/jpeg"/>
        <Default Extension="jpg" ContentType="image/jpeg"/>
        <Default Extension="gif" ContentType="image/gif"/>
        <Override PartName="/word/document.xml" ContentType="\(XMLNamespaces.contentTypeDocument)"/>
        <Override PartName="/word/styles.xml" ContentType="\(XMLNamespaces.contentTypeStyles)"/>
        <Override PartName="/word/settings.xml" ContentType="\(XMLNamespaces.contentTypeSettings)"/>
        """

        if hasNumbering {
            xml += "<Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>"
        }

        for override in additionalOverrides {
            xml += "<Override PartName=\"\(override.partName)\" ContentType=\"\(override.contentType)\"/>"
        }

        xml += "</Types>"
        return xml
    }

    private func buildDocumentRelsXML(hasNumbering: Bool, additionalRels: [(id: String, type: String, target: String)]) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="\(XMLNamespaces.relationshipStyles)" Target="styles.xml"/>
        <Relationship Id="rId2" Type="\(XMLNamespaces.relationshipSettings)" Target="settings.xml"/>
        """

        if hasNumbering {
            xml += "<Relationship Id=\"rId3\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>"
        }

        for rel in additionalRels {
            if rel.type == XMLNamespaces.relationshipHyperlink {
                xml += "<Relationship Id=\"\(rel.id)\" Type=\"\(rel.type)\" Target=\"\(escapeXMLAttribute(rel.target))\" TargetMode=\"External\"/>"
            } else {
                xml += "<Relationship Id=\"\(rel.id)\" Type=\"\(rel.type)\" Target=\"\(rel.target)\"/>"
            }
        }

        xml += "</Relationships>"
        return xml
    }

    private func escapeXML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }

    private func escapeXMLAttribute(_ string: String) -> String {
        var result = escapeXML(string)
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }
}
