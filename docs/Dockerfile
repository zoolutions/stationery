# syntax = docker/dockerfile:1
# docs-kit Dockerfile v1.1.1 — regenerate/diff: bin/rails g docs_kit:install
#
# A standalone docs-kit site: a lean, multi-stage production image. The final
# stage carries only the runtime (Ruby + the installed bundle + the app), never
# the build toolchain (build-essential, git, bun) — those live in the throwaway
# `build` stage. Pair it with the shipped .dockerignore so the build context
# stays small (no node_modules, .git, logs, specs, coverage).
#
# The docs app depends on the gem via `gem "stationery", path: ".."` and renders
# the repo's README.md, CHANGELOG.md and examples/, so the build context is the
# REPO ROOT (not docs/): the gem lives at /rails and the docs app at /rails/docs.
# Build with `docker build -f docs/Dockerfile .` from the repo root (dash:
# context: "..", which the reusable deploy workflow passes as build_context ".").
# docs/Dockerfile.dockerignore keeps that context small.

ARG RUBY_VERSION=3.4.2
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# The gem lives at /rails, the Rails app at /rails/docs.
WORKDIR /rails/docs

ARG BUN_VERSION=1.3.2
ENV BUN_INSTALL="/usr/local/bun" \
    PATH="/usr/local/bun/bin:$PATH" \
    BUNDLE_DEPLOYMENT="0" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"

# Base packages the RUNTIME needs (jemalloc for a smaller/faster heap, curl for
# the container healthcheck). Anything only the build needs goes in `build`.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# --- Build stage (throwaway — its layers never reach the final image) ---------
FROM base AS build

# Toolchain to compile native gems + fetch bun. Skip the apt cleanup: this whole
# stage is discarded.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config unzip
RUN curl -fsSL https://bun.sh/install | bash -s -- "bun-v${BUN_VERSION}"

# Install gems first (cached until Gemfile/Gemfile.lock change), then prune the
# bundler cache + any git-sourced gem checkouts so they don't bloat the layer.
COPY stationery.gemspec /rails/
COPY lib/stationery/version.rb /rails/lib/stationery/
COPY docs/Gemfile docs/Gemfile.lock ./
# Frozen is off: the path gem's version (and its gemspec file list) moves with
# every release, and a frozen bundle refuses to re-resolve it; the lock still
# pins every other gem. Same call as the other docs-kit sites.
RUN bundle config set frozen false && bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install JS deps (the Tailwind/daisyUI CLI), then the app.
COPY docs/package.json docs/bun.lock* ./
RUN bun install --frozen-lockfile
COPY . /rails/

# assets:precompile runs `bun run build:css` via the css:build rake enhance.
# Drop the node_modules + bun cache afterwards — the built CSS is all we keep.
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile && \
    rm -rf node_modules .bun tmp/cache


# --- Final stage --------------------------------------------------------------
FROM base

# dash's validate_image greps this label on a --skip-push deploy; it must equal
# `service:` in config/deploy.yml. The reusable deploy workflow also stamps it,
# but keeping it here means `docker build` alone produces a dash-valid image.
LABEL service="stationery"

# Copy ONLY the built artifacts from the build stage: the installed bundle and
# the app (with precompiled assets). No toolchain, no node_modules.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run as a non-root user; own only the runtime dirs it writes.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R 1000:1000 /rails/docs/log /rails/docs/tmp
USER 1000:1000

EXPOSE 3000
# Thruster fronts Puma (HTTP caching + compression + X-Sendfile). It listens on
# HTTP_PORT and proxies to Puma on TARGET_PORT (it sets PORT for the child, which
# config/puma.rb reads). HTTP_PORT MUST be the port traffic is routed to (dash's
# `app_port`, the EXPOSE above) — Thruster's default is 80, which the non-root
# user can't reliably bind AND which dash-proxy (app_port: 3000) would never
# route to, silently bypassing Thruster straight into Puma.
ENV HTTP_PORT="3000" \
    TARGET_PORT="3001"
CMD ["./bin/thrust", "./bin/rails", "server"]
