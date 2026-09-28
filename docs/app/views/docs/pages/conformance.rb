# frozen_string_literal: true

class Views::Docs::Pages::Conformance < DocsUI::Page
  title "PDF/A and PDF/UA"
  eyebrow "Guide"

  def lead = "Archival (PDF/A), accessible (PDF/UA-1), e-invoice (Factur-X) and digitally signed output, claimed only when the file keeps it."

  def content
    DocsUI::Section("Claiming a level", description: "At class level or per render.") do
      md <<~'MD'
        ```ruby
        class InvoicePdf < Stationery::Document
          conformance :pdf_a3b            # archival: :pdf_a2b or :pdf_a3b
        end

        class ReportPdf < Stationery::Document
          conformance :pdf_a3b, :pdf_ua1  # archival and accessible
          metadata title: "Annual report 2026", lang: "en"
        end

        InvoicePdf.new(invoice).to_pdf(conformance: nil)      # one render without the claim
        InvoicePdf.new(invoice).to_pdf(conformance: :pdf_a2b) # or with another level
        ```

        One PDF/A level and PDF/UA-1 combine; two PDF/A levels or an unknown name raise `ArgumentError`
        where they are declared. Subclasses inherit the levels. Without `conformance` a render is byte for
        byte what it was before.
      MD
    end

    DocsUI::Section("What each level guarantees") do
      md <<~'MD'
        | Level | Standard | What is written |
        | --- | --- | --- |
        | `:pdf_a2b` | ISO 19005-2, level B | An sRGB `OutputIntent` with the embedded ICC profile, `pdfaid:part 2` / `pdfaid:conformance B` in XMP, the print flag (`/F 4`) on every annotation |
        | `:pdf_a3b` | ISO 19005-3, level B | The same with `pdfaid:part 3`; [embedded files](/docs/pages#embedded-files) of any type are allowed, each with its `/AFRelationship` |
        | `:pdf_ua1` | ISO 14289-1 | A tagged PDF, `pdfuaid:part 1` in XMP, the title shown by the viewer, tab order by structure (`/Tabs /S`), a description (`/Contents`) on every link annotation |

        Level B means the visual appearance is reproducible: every font is embedded (they always are, as
        subsets with a ToUnicode map) and colour is defined through the output intent. The bundled profile
        is the ICC's `sRGB2014.icc`. Transparency (`opacity:`, shadows, PNG alpha) is allowed from PDF/A-2 on.

        With both a PDF/A level and PDF/UA-1, the XMP packet also describes the `pdfuaid` schema to PDF/A
        (`pdfaExtension:schemas`), which PDF/A requires of every schema it does not know.

        A link's description is its URL, or `Page 3` for a link inside the document.

        Form fields conform as they are: their appearances draw with the document's embedded fonts and
        with paths, and every field carries an accessible name (`/TU`, from `tooltip:`, its label or its
        name). Under a level the form leaves out `NeedAppearances` and the ZapfDingbats entry it
        otherwise lists for viewers that redraw a button's mark.
      MD
    end

    DocsUI::Section("What raises", description: "A file is never mislabelled.") do
      md <<~'MD'
        | Situation | Level | Raises |
        | --- | --- | --- |
        | `encrypt:` | PDF/A | `ArgumentError` (PDF/A forbids encryption; PDF/UA allows it) |
        | `attach_file` / `attachments:` | PDF/A-2b | `ArgumentError`: part 2 only embeds PDF/A files, use `:pdf_a3b` |
        | No `metadata title:` or `lang:` | PDF/UA-1 | `Stationery::ConformanceError` listing what is missing |
        | An image or drawing without `alt:` | PDF/UA-1 | `ConformanceError`; mark decoration with `alt: false` |
        | A form field made without a font book (`Forms::Field.new` placed with `canvas.widget`) | every level | `ConformanceError` naming the field: it draws with the standard Helvetica, which is not embedded. Fields from `text_field`, `select`, `checkbox`, `radio` and `signature_field` draw with the document's embedded fonts and are allowed |

        ```ruby
        begin
          ReportPdf.new(report).to_pdf
        rescue Stationery::ConformanceError => e
          e.levels # => [:pdf_a3b, :pdf_ua1]
          e.issues # => ["image on page 2 has no alt: text"]
        end
        ```

        CMYK colours (`[c, m, y, k]`) and CMYK JPEGs are not covered by the sRGB output intent. They are
        reported as a `ConformanceIssue` [warning](/docs/warnings), so `strict` refuses them; without
        `strict` the file is written and a validator will flag it.
      MD

      DocsUI::Callout(:note, title: "What a machine can check") do
        "conformance :pdf_ua1 checks what a machine can check. Whether the alt texts describe the images, " \
          "the headings nest sensibly and the reading order makes sense is still yours to review."
      end
    end

    DocsUI::Section("Factur-X / ZUGFeRD e-invoices", description: "One PDF for people and for accounting software.") do
      md <<~'MD'
        A Factur-X invoice (ZUGFeRD in Germany) is a PDF/A-3b file with the invoice embedded as Cross
        Industry Invoice XML. `factur_x` does the PDF side in one line:

        ```ruby
        class InvoicePdf < Stationery::Document
          metadata title: "Invoice", lang: "en"
          factur_x(profile: :en16931) { @invoice.to_cii_xml } # evaluated in the document, per render
          # factur_x :invoice_xml                             # or a method name
          # factur_x File.read("factur-x.xml")                # or the XML itself

          def initialize(invoice) = (super(); @invoice = invoice)
        end

        InvoicePdf.new(invoice).to_pdf(factur_x: { xml:, profile: :extended }) # per render; nil for none
        ```

        | What | Written |
        | --- | --- |
        | Conformance | `:pdf_a3b`, added to declared levels such as `:pdf_ua1`; declaring `:pdf_a2b` raises |
        | Embedded file | `factur-x.xml`, `text/xml`, description "Factur-X Invoice", `/Params` with size, checksum and modification date, listed in `/EmbeddedFiles` and `/AF` |
        | XMP | `fx:DocumentType INVOICE`, `fx:DocumentFileName`, `fx:Version`, `fx:ConformanceLevel`, and the `fx` schema described through `pdfaExtension:schemas` |

        | `profile:` | `fx:ConformanceLevel` | File | `/AFRelationship` |
        | --- | --- | --- | --- |
        | `:minimum` | `MINIMUM` | `factur-x.xml` | `Data` |
        | `:basic_wl` | `BASIC WL` | `factur-x.xml` | `Data` |
        | `:basic` | `BASIC` | `factur-x.xml` | `Alternative` |
        | `:en16931` (default) | `EN 16931` | `factur-x.xml` | `Alternative` |
        | `:extended` | `EXTENDED` | `factur-x.xml` | `Alternative` |
        | `:xrechnung` | `XRECHNUNG` | `xrechnung.xml` | `Alternative` |

        `filename:`, `version:` (default `"1.0"`) and `relationship:` override the defaults; ZUGFeRD 1.0
        named its file `ZUGFeRD-invoice.xml`.

        Stationery carries the XML, it does not write or validate it. Anything that does not start with
        `<?xml` or `<rsm:CrossIndustryInvoice` raises `ArgumentError`; what is inside comes from your
        invoicing code or a library made for it. The [e-invoice example](/docs/examples#factur-x-e-invoice)
        builds a minimal EN 16931 document from its line items in plain Ruby, marked as sample code.

        Everything PDF/A-3b asks still applies: `encrypt:` raises. Form fields and a signature are fine.
        Without `factur_x` a render is byte for byte what it was.
      MD

      DocsUI::Callout(:tip, title: "Validate the XML too") do
        "veraPDF checks the PDF/A-3 container. The invoice itself is checked by a Factur-X validator: " \
          "rake verify:factur_x runs Mustang on the example, against the EN 16931 schema and business rules."
      end
    end

    DocsUI::Section("Digital signatures", description: "Who issued the file, and that it has not changed.") do
      md SourceMarkdown.readme_section("Digital signatures")

      md <<~'MD'
        | What | Written |
        | --- | --- |
        | Signature dictionary | `/Type /Sig`, `/Filter /Adobe.PPKLite`, `/SubFilter /ETSI.CAdES.detached`, `/M`, `/Name`, and `/Reason`, `/Location`, `/ContactInfo` when given |
        | `/ByteRange` | The whole file but the `/Contents` string: `[0 a b c]` with `b + c` the file's size |
        | `/Contents` | The CMS SignedData in hex, padded with zeros to `contents_size:` bytes, never encrypted |
        | Signed attributes | content type, message digest (SHA-256), ESS signing-certificate-v2; no signing time |
        | Unsigned attributes | With `timestamp:`, the TSA's RFC 3161 token over the signature value (`id-aa-signatureTimeStampToken`): PAdES baseline B-T |
        | Form | `/SigFlags 3`, no `NeedAppearances`; the field's `/V` is the signature dictionary |
        | Invisible signature | A field `Signature1` whose widget is `/Rect [0 0 0 0]`, `/F 132` (print, locked), on the first page |

        `Inspector#signatures` reports the token as `timestamp: { time:, tsa:, valid: }`: `valid` when it
        is over this signature and verifies against the TSA certificates it carries.
        `TSA_URL=http://timestamp.digicert.com bundle exec rake verify:timestamp` timestamps a signed
        PDF/A-3b render of the invoice example and checks it with the inspector, `pdfsig` and veraPDF;
        it needs the network, so it is not part of CI.

        Check a signed file with poppler's `pdfsig`, or the signature itself with OpenSSL:

        ```sh
        pdfsig -nocert contract.pdf
        #  - Signature Type: ETSI.CAdES.detached
        #  - Total document signed
        #  - Signature Validation: Signature is Valid.
        openssl cms -verify -inform DER -in signature.der -content signed-bytes.bin -binary -noverify -out /dev/null
        # CMS Verification successful
        ```
      MD

      DocsUI::Callout(:note, title: "Valid is not trusted") do
        "A valid signature says the file is what the certificate's holder signed. Whether a viewer shows a " \
          "green mark depends on the certificate: one issued by an authority on the viewer's trust list " \
          "(the EU trusted lists, Adobe's AATL) is trusted, a self-signed one is valid but unknown."
      end
    end

    DocsUI::Section("Validating with veraPDF", description: "The reference validator, through Docker.") do
      md <<~'MD'
        `bundle exec rake verify:conformance` renders `examples/invoice.rb` and `examples/e_invoice.rb`
        as PDF/A-3b, and `examples/report.rb` and `examples/form.rb` as PDF/A-3b plus PDF/UA-1, the
        invoice and the form once more with a signature, and validates them with
        [veraPDF](https://verapdf.org) in a container (`verapdf/cli`); the gem's CI runs it on every push.
        Validate your own documents the same way:

        ```sh
        docker run --rm -v "$PWD:/data:ro" verapdf/cli --format text -v --flavour 3b /data/invoice.pdf
        # PASS /data/invoice.pdf 3b
        docker run --rm -v "$PWD:/data:ro" verapdf/cli --format text -v --flavour ua1 /data/report.pdf
        ```

        Flavours are `2b`, `3b` and `ua1`; `-v` lists the failed rules by clause.

        `bundle exec rake verify:factur_x` validates the e-invoice example with
        [Mustang](https://www.mustangproject.org), which checks the PDF/A-3 file and the embedded XML
        together. It downloads the pinned Mustang CLI once into `tmp/factur_x/` and runs it in a Java
        container:

        ```sh
        docker run --rm -v "$PWD:/data" -w /data eclipse-temurin:21-jre \
          java -jar Mustang-CLI-2.26.0.jar --action validate --source invoice.pdf --no-notices
        # <summary status="valid"/>
        ```
      MD
    end

    DocsUI::Section("In tests") do
      md <<~'MD'
        ```ruby
        it { is_expected.to have_conformance(:pdf_a3b) }
        it { is_expected.to have_conformance(:pdf_a3b, :pdf_ua1) }

        it { is_expected.to have_factur_x(profile: :en16931) }
        it { is_expected.to have_signature(name: "Acme Legal") }

        assert_pdf_conformance pdf, :pdf_a3b
        assert_factur_x pdf, profile: :en16931
        assert_pdf_signature pdf, name: "Acme Legal"
        Stationery::Testing::Inspector.new(pdf).conformance # => [:pdf_a3b, :pdf_ua1]
        Stationery::Testing::Inspector.new(pdf).factur_x    # => { profile: :en16931, filename: "factur-x.xml", … }
        Stationery::Testing::Inspector.new(pdf).signatures  # => [{ field: "approval", signer: "CN=…", valid: true, … }]
        ```

        These read the claim from the XMP packet, and for an e-invoice the embedded file it names. They
        do not validate the file: that is veraPDF's and Mustang's job. A signature is different:
        `have_signature` recomputes the digest over the signed bytes and verifies the CMS against the
        certificate it carries (not the certificate's trust).
      MD
    end
  end
end
