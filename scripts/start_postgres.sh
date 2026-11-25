#!/bin/bash
# Start Postgres. A rebuilt container starts out with a self-signed
# certificate, so first put back the Let's Encrypt one if we have it.
set -e

/usr/local/bin/install_pg_cert.sh --no-reload || echo "Could not install the Let's Encrypt certificate, starting Postgres anyway." >&2

exec su postgres -c '/usr/lib/postgresql/17/bin/postgres -D /var/lib/postgresql/17/main -c config_file=/etc/postgresql/17/main/postgresql.conf'
