#!/bin/bash
# Entrypoint script for Bindocsis container
# Auto-generates SECRET_KEY_BASE if not provided

if [ -z "$SECRET_KEY_BASE" ]; then
  echo "No SECRET_KEY_BASE provided, generating one..."
  export SECRET_KEY_BASE=$(openssl rand -hex 64)
fi

exec "$@"
