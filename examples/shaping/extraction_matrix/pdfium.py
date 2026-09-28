# The text of a PDF as PDFium reads it (FPDFText_GetText, what Chrome copies): python pdfium.py file.pdf
import sys

import pypdfium2

document = pypdfium2.PdfDocument(sys.argv[1])
for page in document:
    sys.stdout.write(page.get_textpage().get_text_range().replace("\r\n", "\n") + "\n")
