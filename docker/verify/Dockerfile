# syntax=docker/dockerfile:1
# `stationery verify` with every engine that runs on Linux: qpdf, Poppler,
# MuPDF, PDFium (pypdfium2) and pdf.js (pdfjs-dist under Node). Built from
# the repository root:
#
#   docker build -f docker/verify/Dockerfile -t stationery-verify .
#   docker run --rm -v "$PWD:/data:ro" stationery-verify /data/invoice.pdf
#
# The pins are exact; bumping one is a pull request that runs the corpus
# (rake verify:readers) through the image.
ARG RUBY_VERSION=3.4
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-trixie-slim AS node

FROM ruby:${RUBY_VERSION}-slim-trixie
ARG PYPDFIUM2_VERSION=5.13.0
ARG PDFJS_VERSION=6.3.289
ARG PDF_READER_VERSION=2.16.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends qpdf poppler-utils mupdf-tools python3-venv \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

RUN python3 -m venv /opt/pdfium \
 && /opt/pdfium/bin/pip install --no-cache-dir "pypdfium2==${PYPDFIUM2_VERSION}"
RUN mkdir -p /opt/pdfjs \
 && npm install --prefix /opt/pdfjs --no-audit --no-fund "pdfjs-dist@${PDFJS_VERSION}" \
 && npm cache clean --force

WORKDIR /src
COPY stationery.gemspec README.md CHANGELOG.md LICENSE.txt ./
COPY lib lib
COPY exe exe
RUN gem build stationery.gemspec \
 && gem install --no-document ./stationery-*.gem "pdf-reader:${PDF_READER_VERSION}" \
 && rm -rf /src

ENV STATIONERY_PYTHON=/opt/pdfium/bin/python \
    STATIONERY_PDFJS=/opt/pdfjs/node_modules/pdfjs-dist
RUN useradd --create-home verify
USER verify
WORKDIR /data
ENTRYPOINT ["stationery", "verify"]
