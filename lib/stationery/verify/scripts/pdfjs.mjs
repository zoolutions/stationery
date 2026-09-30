// Reads PDFs with pdf.js (pdfjs-dist's legacy build under Node) and prints
// one JSON object of facts per file, one per line, for Stationery::Verify.
//
//   STATIONERY_PDFJS=/path/to/node_modules/pdfjs-dist node pdfjs.mjs FILE…
//
// STATIONERY_VERIFY_PASSWORD opens an encrypted file. Node has no canvas, so
// a page "paints" when its operator list holds a painting operator.
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import path from "node:path";

const root = process.env.STATIONERY_PDFJS;
const pdfjs = await import(pathToFileURL(path.join(root, "legacy/build/pdf.mjs")).href);
const { getDocument, VerbosityLevel, OPS, AnnotationType } = pdfjs;
const password = process.env.STATIONERY_VERIFY_PASSWORD || undefined;
const write = process.stdout.write.bind(process.stdout);
const PAINTS = new Set(
  ["fill", "eoFill", "stroke", "fillStroke", "eoFillStroke", "closeStroke", "closeFillStroke", "closeEOFillStroke",
   "showText", "showSpacedText", "nextLineShowText", "nextLineSetSpacingShowText", "shadingFill",
   "paintImageXObject", "paintInlineImageXObject", "paintImageMaskXObject", "paintSolidColorImageMask",
   "paintImageXObjectRepeat", "paintImageMaskXObjectRepeat", "paintImageMaskXObjectGroup", "constructPath"]
    .filter((name) => name in OPS).map((name) => OPS[name])
);

let messages = [];
for (const level of ["log", "info", "warn", "error"]) {
  console[level] = (...args) => messages.push(args.map(String).join(" "));
}

// pdf.js 6 answers Maps where earlier versions answered plain objects.
const entries = (found) => (found instanceof Map ? [...found] : Object.entries(found || {}));

async function titles(items) {
  const found = [];
  for (const item of items || []) found.push(item.title, ...(await titles(item.items)));
  return found;
}

async function target(document, annotation) {
  if (annotation.url) return { uri: annotation.url };
  let dest = annotation.dest;
  if (typeof dest === "string") dest = await document.getDestination(dest);
  if (!Array.isArray(dest)) return {};
  const ref = dest[0];
  const index = typeof ref === "number" ? ref : await document.getPageIndex(ref);
  return { page: index + 1 };
}

async function page(document, number) {
  const page = await document.getPage(number);
  const text = (await page.getTextContent()).items.map((item) => item.str ?? "").join(" ");
  const operators = await page.getOperatorList();
  const painted = operators.fnArray.some((fn) => PAINTS.has(fn));
  const annotations = await page.getAnnotations();
  const links = [];
  for (const annotation of annotations) {
    if (annotation.annotationType === AnnotationType.LINK) links.push(await target(document, annotation));
  }
  const widgets = annotations.filter((annotation) => annotation.annotationType === AnnotationType.WIDGET);
  const structure = await page.getStructTree();
  return { page: { number, text, painted, links }, widgets, structure: structure !== null };
}

function fields(objects, widgets) {
  return entries(objects).map(([name, kids]) => {
    const values = kids.map((kid) => kid.value).filter((value) => value !== undefined && value !== null);
    const own = widgets.filter((widget) => widget.fieldName === name);
    return {
      name,
      value: typeof values[0] === "string" ? values[0] : null,
      appearance: own.length === 0 ? null : own.every((widget) => widget.hasAppearance),
    };
  });
}

async function facts(file) {
  messages = [];
  const result = { file, pages: [], errors: [] };
  try {
    const data = new Uint8Array(await readFile(file));
    const task = getDocument({
      data, password, verbosity: VerbosityLevel.WARNINGS, isEvalSupported: false,
      standardFontDataUrl: path.join(root, "standard_fonts") + path.sep,
      cMapUrl: path.join(root, "cmaps") + path.sep, cMapPacked: true,
      wasmUrl: path.join(root, "wasm") + path.sep,
    });
    const document = await task.promise;
    const widgets = [];
    let structure = false;
    for (let number = 1; number <= document.numPages; number++) {
      const read = await page(document, number);
      result.pages.push(read.page);
      widgets.push(...read.widgets);
      structure ||= read.structure;
    }
    result.outline = await titles(await document.getOutline());
    result.fields = fields(await document.getFieldObjects(), widgets);
    result.attachments = entries(await document.getAttachments()).map(([, file]) => file.filename);
    result.structure = structure;
    await task.destroy();
  } catch (error) {
    result.errors.push(String(error?.message || error));
  }
  result.warnings = messages;
  return result;
}

for (const file of process.argv.slice(2)) write(JSON.stringify(await facts(file)) + "\n");
