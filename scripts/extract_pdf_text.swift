import Foundation
import PDFKit

guard CommandLine.arguments.count == 2,
      let document = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    fputs("Usage: swift scripts/extract_pdf_text.swift PDF_PATH\n", stderr)
    exit(2)
}

print("PAGE_COUNT=\(document.pageCount)")
for index in 0..<document.pageCount {
    print(document.page(at: index)?.string ?? "")
}
