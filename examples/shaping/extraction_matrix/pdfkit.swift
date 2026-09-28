// The text of a PDF as PDFKit reads it, which is what Preview copies: swift pdfkit.swift file.pdf
import Foundation
import PDFKit

guard let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else { exit(1) }
print(document.string ?? "")
