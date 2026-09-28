// The text of a PDF as pdf.js reads it: node pdfjs.mjs path/to/node_modules/pdfjs-dist file.pdf
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const [root, file] = process.argv.slice(2);
const { getDocument } = await import(pathToFileURL(join(root, "legacy/build/pdf.mjs")).href);
const document = await getDocument({
  data: new Uint8Array(readFileSync(file)),
  standardFontDataUrl: join(root, "standard_fonts/"),
  verbosity: 0,
}).promise;

for (let number = 1; number <= document.numPages; number++) {
  const page = await document.getPage(number);
  const content = await page.getTextContent();
  process.stdout.write(content.items.map((item) => item.str + (item.hasEOL ? "\n" : "")).join("") + "\n");
}
