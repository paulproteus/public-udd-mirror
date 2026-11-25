#!/bin/bash
# Copy the Let's Encrypt certificate to where Postgres reads it from, and ask
# Postgres to reload it. Postgres re-reads ssl_cert_file/ssl_key_file on a
# configuration reload, so existing connections are not interrupted.
#
# Usage: install_pg_cert.sh [--no-reload]
set -e
set -u

LIVE_DIR="/etc/letsencrypt/live/udd-mirror"
PG_TLS_DIR="/etc/postgresql/17/main/tls"

if [ ! -f "$LIVE_DIR/fullchain.pem" ] || [ ! -f "$LIVE_DIR/privkey.pem" ]; then
    echo "No Let's Encrypt certificate in $LIVE_DIR, leaving the Postgres certificate alone."
    exit 0
fi

# Postgres refuses to start with a key that is readable by others, or that is
# not owned by the postgres user (or root).
install -o postgres -g postgres -m 0644 "$LIVE_DIR/fullchain.pem" "$PG_TLS_DIR/server.crt.new"
install -o postgres -g postgres -m 0600 "$LIVE_DIR/privkey.pem" "$PG_TLS_DIR/server.key.new"
mv -f "$PG_TLS_DIR/server.crt.new" "$PG_TLS_DIR/server.crt"
mv -f "$PG_TLS_DIR/server.key.new" "$PG_TLS_DIR/server.key"
echo "Installed the Let's Encrypt certificate into $PG_TLS_DIR."

if [ "${1:-}" != "--no-reload" ]; then
    if su postgres -c "psql -qAt -c 'SELECT pg_reload_conf()'" > /dev/null; then
        echo "Postgres reloaded its TLS certificate."
    else
        echo "Could not reload Postgres, it will pick up the certificate when it starts." >&2
    fi
fi
