// Reads PDFs with Apple's PDFKit (what Preview and Safari show) and prints
// one JSON object of facts per file, one per line, for Stationery::Verify.
//
//   swift pdfkit.swift FILE…
//
// STATIONERY_VERIFY_PASSWORD opens an encrypted file.
import CoreGraphics
import Foundation
import PDFKit

let password = ProcessInfo.processInfo.environment["STATIONERY_VERIFY_PASSWORD"] ?? ""
let scale: CGFloat = 0.5 // 36 dpi: enough for a page's text to darken a pixel

func painted(_ page: PDFPage) -> Bool {
    let box = page.bounds(for: .mediaBox)
    let width = max(Int(box.width * scale), 1), height = max(Int(box.height * scale), 1)
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    guard let data = context.data else { return false }
    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
    return (0 ..< width * height).contains { pixels[$0] != 255 }
}

func target(_ annotation: PDFAnnotation, in document: PDFDocument) -> [String: Any] {
    if let url = annotation.url ?? (annotation.action as? PDFActionURL)?.url { return ["uri": url.absoluteString] }
    let destination = annotation.destination ?? (annotation.action as? PDFActionGoTo)?.destination
    if let page = destination?.page { return ["page": document.index(for: page) + 1] }
    return [:]
}

func titles(_ item: PDFOutline?) -> [String] {
    guard let item else { return [] }
    return (0 ..< item.numberOfChildren).flatMap { index -> [String] in
        let child = item.child(at: index)!
        return [child.label ?? ""] + titles(child)
    }
}

func facts(_ path: String) -> [String: Any] {
    var result: [String: Any] = ["file": path, "pages": [], "errors": [], "warnings": []]
    guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
        result["errors"] = ["PDFKit cannot open the file"]
        return result
    }
    if document.isLocked && !document.unlock(withPassword: password) {
        result["errors"] = ["PDFKit cannot unlock the file"]
        return result
    }
    var pages: [[String: Any]] = [], fields: [[String: Any]] = []
    for index in 0 ..< document.pageCount {
        guard let page = document.page(at: index) else {
            result["errors"] = ["PDFKit cannot read page \(index + 1)"]
            return result
        }
        var links: [[String: Any]] = []
        for annotation in page.annotations {
            if annotation.type == "Link" { links.append(target(annotation, in: document)) }
            if annotation.type == "Widget", let name = annotation.fieldName {
                let text = annotation.widgetFieldType == .text ? annotation.widgetStringValue : nil
                // PDFKit keeps a widget's /AP to itself: the appearance is not reported.
                fields.append(["name": name, "value": text as Any, "appearance": NSNull()])
            }
        }
        pages.append(["number": index + 1, "text": page.string ?? "", "painted": painted(page), "links": links])
    }
    result["pages"] = pages
    result["outline"] = titles(document.outlineRoot)
    result["fields"] = fields
    return result
}

for path in CommandLine.arguments.dropFirst() {
    let data = try! JSONSerialization.data(withJSONObject: facts(path))
    FileHandle.standardOutput.write(data + Data("\n".utf8))
}
