# Multi-stage Dockerfile for Rehab Exercise Tracking System
# Optimized for production deployment with proper security and performance

FROM hexpm/elixir:1.16-erlang-27-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set build ENV
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
RUN mix deps.get --only prod

# Copy source code
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Compile the application
RUN mix compile

# Build assets (if any)
# RUN mix assets.deploy

# Build release
RUN mix release

# ====================================
# Runtime Stage
# ====================================
FROM alpine:3.18 AS runtime

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++

# Create non-root user
RUN addgroup -g 1001 -S rehab && \
    adduser -S -D -H -u 1001 -h /app -s /bin/bash -G rehab rehab

# Create app directory
WORKDIR /app

# Copy the release from builder stage
COPY --from=builder --chown=rehab:rehab /app/_build/prod/rel/rehab_tracking ./

# Create necessary directories
RUN mkdir -p /app/tmp /app/log /app/data && \
    chown -R rehab:rehab /app

# Switch to non-root user
USER rehab

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD ./bin/rehab_tracking rpc "RehabTracking.HealthCheck.check()"

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000
ENV PHX_SERVER=true

# Start the application
CMD ["./bin/rehab_tracking", "start"]

# ====================================
# Development Stage (optional)
# ====================================
FROM hexpm/elixir:1.16-erlang-27-alpine AS development

# Install development dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    inotify-tools

# Set development ENV
ENV MIX_ENV=dev

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get

# Copy source code
COPY . .

# Compile for development
RUN mix compile

# Expose port for development
EXPOSE 4000

# Development command
CMD ["mix", "phx.server"]

# ====================================
# Test Stage
# ====================================
FROM development AS test

# Set test environment
ENV MIX_ENV=test

# Install test dependencies
RUN mix deps.get --only test

# Copy test files
COPY test ./test

# Run tests
RUN mix test

# ====================================
# Production-ready Build
# ====================================
FROM runtime AS production

# Add production configurations
COPY --chown=rehab:rehab config/prod.exs config/
COPY --chown=rehab:rehab config/runtime.exs config/

# Security hardening
RUN chmod -R 750 /app && \
    find /app -type f -exec chmod 640 {} \; && \
    chmod +x /app/bin/rehab_tracking

# Set production labels
LABEL maintainer="Rehab Tracking Team" \
      version="1.0.0" \
      description="Event-sourced rehabilitation exercise tracking system" \
      org.opencontainers.image.source="https://github.com/org/rehab-tracking" \
      org.opencontainers.image.vendor="Healthcare Technology Inc" \
      org.opencontainers.image.title="Rehab Exercise Tracker" \
      org.opencontainers.image.description="HIPAA-compliant event-sourced system for tracking rehabilitation exercises"

# Final security check - ensure no secrets in image
RUN if find /app -name "*.secret" -o -name "*.key" -o -name "*password*" | grep -q .; then \
      echo "ERROR: Secret files found in image" && exit 1; \
    fi