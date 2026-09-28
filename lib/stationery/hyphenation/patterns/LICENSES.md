# Hyphenation patterns

The `*.pat.txt` and `*.hyp.txt` files in this directory are the plain-text
(UTF-8) pattern and exception lists from the TeX `hyph-utf8` package
(https://github.com/hyphenation/tex-hyphen, `hyph-utf8/tex/generic/hyph-utf8/patterns/txt/`),
unmodified. Each file's own copyright and licence follow, copied from the header
of its `.tex` source in the same package. The Ruby code that reads them
(`lib/stationery/hyphenation.rb`) is stationery's and under stationery's licence.

## en-us.pat.txt, en-us.hyp.txt — Hyphenation patterns for American English

Copyright (C) 1990, 2004, 2005 Gerard D.C. Kuiken. Source: `hyph-en-us.tex`
(`ushyphmax.tex`, version 2005-05-30). Based on Liang's patterns and the
Hyphenation Exception Log published in TUGboat, Volume 10 (1989), No. 3.

> Copying and distribution of this file, with or without modification, are
> permitted in any medium without royalty provided the copyright notice and
> this notice are preserved.

Typesetting minimums: 2 letters before a break, 3 after.

## de-1996.pat.txt — German Hyphenation Patterns (Reformed Orthography, 2006)

TeX-Trennmuster für die reformierte (2006) deutsche Rechtschreibung, version
2024-02-28, by the Deutschsprachige Trennmustermannschaft (trennmuster@dante.de).
Copyright (c) 2013-2024 Stephan Hennig, Werner Lemberg, Günter Milde, Sander van
Geloven, Georg Pfeiffer, Gisbert W. Selke, Tobias Wendorf, Keno Wehr. Source:
`hyph-de-1996.tex`; generated from
https://repo.or.cz/w/wortliste.git?a=commit;h=304aaa2188a75e57afe36bad0443d90a9c715b8e.
Licence: MIT (https://opensource.org/licenses/mit-license.php).

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the “Software”), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

Typesetting minimums: 2 letters before a break, 2 after.

## sv.pat.txt — Hyphenation patterns for Swedish

Copyright (C) 1994 Jan Michael Rynning (jmr (at) incolumitas.se), version
1994-03-03. Source: `hyph-sv.tex`. Licence: LaTeX Project Public License,
version 1.2 or later (https://www.latex-project.org/lppl/). This file is
distributed unmodified, as the "Current Maintainer" released it; the LPPL
requires that a modified version be renamed and identified as such.

Typesetting minimums: 2 letters before a break, 2 after.
