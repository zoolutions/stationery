"""Reads PDFs with PDFium (pypdfium2) and prints one JSON object of facts per
file, one per line, for Stationery::Verify.

    python3 pdfium.py FILE...

STATIONERY_VERIFY_PASSWORD opens an encrypted file.
"""
import ctypes
import json
import os
import sys

import pypdfium2 as pdfium
import pypdfium2.raw as raw

PASSWORD = os.environ.get("STATIONERY_VERIFY_PASSWORD") or None
SCALE = 0.5  # 36 dpi: enough for a page's text to darken a pixel


def utf16(function, *args):
    size = function(*args, None, 0)
    if size <= 2:
        return ""
    buffer = ctypes.create_string_buffer(size)
    function(*args, ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ushort)), size)
    return buffer.raw[: size - 2].decode("utf-16-le")


def painted(page):
    bitmap = page.render(scale=SCALE, grayscale=True, may_draw_forms=True)
    data = bytes(bitmap.buffer)
    width, stride = bitmap.width * bitmap.n_channels, bitmap.stride
    return any(data[row * stride : row * stride + width].count(255) != width for row in range(bitmap.height))


def target(document, link):
    action = raw.FPDFLink_GetAction(link)
    if action and raw.FPDFAction_GetType(action) == raw.PDFACTION_URI:
        size = raw.FPDFAction_GetURIPath(document.raw, action, None, 0)
        buffer = ctypes.create_string_buffer(size)
        raw.FPDFAction_GetURIPath(document.raw, action, buffer, size)
        return {"uri": buffer.raw[: size - 1].decode("utf-8", "replace")}
    dest = raw.FPDFLink_GetDest(document.raw, link)
    if not dest and action:
        dest = raw.FPDFAction_GetDest(document.raw, action)
    return {"page": raw.FPDFDest_GetDestPageIndex(document.raw, dest) + 1} if dest else {}


def annotations(document, page):
    links, fields = [], []
    form = document.formenv.raw if document.formenv else None
    for index in range(raw.FPDFPage_GetAnnotCount(page.raw)):
        annot = raw.FPDFPage_GetAnnot(page.raw, index)
        subtype = raw.FPDFAnnot_GetSubtype(annot)
        if subtype == raw.FPDF_ANNOT_LINK:
            links.append(target(document, raw.FPDFAnnot_GetLink(annot)))
        elif subtype == raw.FPDF_ANNOT_WIDGET and form:
            value = utf16(raw.FPDFAnnot_GetFormFieldValue, form, annot)
            fields.append({"name": utf16(raw.FPDFAnnot_GetFormFieldName, form, annot),
                           "value": value if raw.FPDFAnnot_GetFormFieldType(form, annot) == raw.FPDF_FORMFIELD_TEXTFIELD else None,
                           "appearance": bool(raw.FPDFAnnot_HasKey(annot, b"AP"))})
        raw.FPDFPage_CloseAnnot(annot)
    return links, fields


def signed(document):
    """The signature fields that hold a signature: PDFium counts empty ones too."""
    count = raw.FPDF_GetSignatureCount(document.raw)
    objects = (raw.FPDF_GetSignatureObject(document.raw, index) for index in range(count))
    return sum(1 for signature in objects if raw.FPDFSignatureObj_GetContents(signature, None, 0) > 0)


def facts(path):
    result = {"file": path, "pages": [], "errors": [], "warnings": []}
    try:
        read(path, result)
    except Exception as error:  # a file PDFium cannot read is that file's error, not the run's
        result["errors"].append(f"{type(error).__name__}: {error}")
    return result


def read(path, result):
    document = pdfium.PdfDocument(path, password=PASSWORD)
    document.init_forms()
    fields = []
    for index in range(len(document)):
        page = document[index]
        links, widgets = annotations(document, page)
        fields.extend(widgets)
        text = page.get_textpage().get_text_range()
        result["pages"].append({"number": index + 1, "text": text, "painted": painted(page), "links": links})
    result["outline"] = [item.get_title() for item in document.get_toc()]
    result["fields"] = fields
    result["signatures"] = {"count": signed(document), "valid": None}
    document.close()


for path in sys.argv[1:]:
    print(json.dumps(facts(path)), flush=True)
