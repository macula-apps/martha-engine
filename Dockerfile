# syntax=docker/dockerfile:1.4
# martha-engine CLI and Server Docker Image (a modified goose; see NOTICE)
# The engine's name, once: it must equal crates/martha-engine-name's ENGINE_NAME.
ARG ENGINE_NAME=martha-engine
# Multi-stage build for minimal final image size

# Build stage
FROM rust:1.82-bookworm AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libdbus-1-dev \
    libclang-dev \
    protobuf-compiler \
    libprotobuf-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /build

# Copy source code
COPY . .

# Build release binaries with optimizations
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
ENV CARGO_PROFILE_RELEASE_LTO=true
ENV CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
ENV CARGO_PROFILE_RELEASE_OPT_LEVEL=z
ENV CARGO_PROFILE_RELEASE_STRIP=true
RUN cargo build --release --package goose-cli

# Runtime stage - minimal Debian
FROM debian:bookworm-slim@sha256:b1a741487078b369e78119849663d7f1a5341ef2768798f7b7406c4240f86aef

ARG ENGINE_NAME

# Install only runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    libdbus-1-3 \
    libgomp1 \
    libxcb1 \
    curl \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /build/target/release/${ENGINE_NAME} /usr/local/bin/${ENGINE_NAME}

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash engine && \
    mkdir -p /home/engine/.config/${ENGINE_NAME} && \
    chown -R engine:engine /home/engine

# Set up environment
ENV PATH="/usr/local/bin:${PATH}"
ENV HOME="/home/engine"
ENV ENGINE_BIN="/usr/local/bin/${ENGINE_NAME}"

# Switch to non-root user
USER engine
WORKDIR /home/engine

# Default to the engine CLI (shell form so the name is not restated; exec keeps it PID 1)
ENTRYPOINT ["/bin/sh", "-c", "exec \"$ENGINE_BIN\" \"$@\"", "--"]
CMD ["--help"]

# Labels for metadata
LABEL org.opencontainers.image.title="${ENGINE_NAME}"
LABEL org.opencontainers.image.description="${ENGINE_NAME} CLI, a modified goose (see NOTICE)"
LABEL org.opencontainers.image.vendor="Macula"
LABEL org.opencontainers.image.source="https://github.com/macula-apps/martha-engine"
