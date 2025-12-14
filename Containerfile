# Containerfile for Bindocsis
# Build: podman build -t bindocsis .
# Run: podman run -p 4555:4555 -e SECRET_KEY_BASE=$(mix phx.gen.secret) bindocsis

# =============================================================================
# Build Stage
# =============================================================================
FROM docker.io/hexpm/elixir:1.18.0-erlang-25.1.2-debian-bullseye-20251208-slim AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv

# Compile the release
RUN mix compile

# Copy runtime config
COPY config/runtime.exs config/

# Create the release
RUN mix release

# =============================================================================
# Runtime Stage
# =============================================================================
FROM docker.io/debian:bullseye-slim AS runner

# Install runtime dependencies
RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

# Create a non-root user
RUN useradd --create-home --shell /bin/bash app
RUN chown -R app:app /app

USER app

# Copy the release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/bindocsis ./

# Copy entrypoint script
COPY --chown=app:app entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create directory for config files (uploads, etc)
RUN mkdir -p /app/data

ENV HOME=/app
ENV PHX_SERVER=true
ENV PORT=4555

# Expose the port
EXPOSE 4555

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:4555/ || exit 1

# Use entrypoint to auto-generate SECRET_KEY_BASE if not provided
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["bin/bindocsis", "start"]
