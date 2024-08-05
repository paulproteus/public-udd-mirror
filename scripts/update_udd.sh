#!/bin/bash
set -e
set -u
USER=$(whoami)
STARTING_CWD="/var/www/html"
LOGFILE="$STARTING_CWD/logs/log.txt"
LOCKFILE="/tmp/update_udd.$USER.lock"
SUCCESS_STAMP="$STARTING_CWD/logs/stamp.txt"

if [ -f "$LOCKFILE" ]; then
    echo "Lockfile present, udd importer already running with PID $(cat "$LOCKFILE")" >&2
    exit 1
fi

TMPDBNAME="udd_$(date +%Y%m%d)_$$"

trap_dropdb() {
    if [ "${1:-}" = GRANT ]; then
        echo "trap invoked, restoring permissions"
        echo "GRANT CONNECT ON DATABASE udd TO public" | sudo -u postgres psql -a
    fi
    echo "trap invoked, deleting the temporary database"
    echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = '${TMPDBNAME}'" | sudo -u postgres psql -a
    sudo -u postgres dropdb "$TMPDBNAME"
    echo "Releasing lock."
    rm -vf "$LOCKFILE"
}

if [ "$USER" != "udd-mirror" ] ; then
    echo "For sysadmin's sake, please run this script as the udd-mirror user"
    echo "This script has been called by $USER"
fi

mkdir -p "$(dirname "$LOGFILE")"

exec &> >(tee -a "$LOGFILE")

printf '\n\n'
echo "============================================================================="
printf '\n\n'
echo "Log started at $(date -u)"
echo $$ > "$LOCKFILE"
echo "lock taken at $LOCKFILE"

UDD_URL=https://udd.debian.org/dumps/udd.dump
UDD_FILENAME=$(basename "$UDD_URL")

# change directory into our happy land
mkdir -p "/tmp/$USER"
cd "/tmp/$USER"

# If we had no success stamp file, create one.
if [ ! -f "$SUCCESS_STAMP" ] ; then
    touch --date=1970-01-01 "$SUCCESS_STAMP"
fi

# Download the UDD dump, if it is newer
echo "Downloading udd.dump"
if ! TZ=UTC wget -N --no-verbose "$UDD_URL"; then
    echo "wget failed!" >&2
    echo "Releasing lock."
    rm -vf "$LOCKFILE"
    exit 1
fi

# Check if it is newer than the last success stamp
if [ "$UDD_FILENAME" -nt "$SUCCESS_STAMP" ] ; then
    # Ensure public access login accounts exist
    if ! sudo -u postgres psql -t -c '\du' |grep -qw udd; then
        echo "CREATE USER 'udd' WITH PASSWORD 'udd'" | sudo -u postgres psql -a
    fi
    if ! sudo -u postgres psql -t -c '\du' |grep -qw udd-mirror; then
        echo "CREATE USER 'udd-mirror' WITH PASSWORD 'udd-mirror'" | sudo -u postgres psql -a
    fi
    if ! sudo -u postgres psql -t -c '\du' |grep -qw public-udd-mirror; then
        echo "CREATE USER 'public-udd-mirror' WITH PASSWORD 'public-udd-mirror'" | sudo -u postgres psql -a
    fi
    sudo -u postgres psql -a <<- "EOF"
    ALTER DEFAULT PRIVILEGES FOR USER "udd" IN SCHEMA "public" GRANT SELECT ON TABLES TO "udd";
    ALTER DEFAULT PRIVILEGES FOR USER "udd-mirror" IN SCHEMA "public" GRANT SELECT ON TABLES TO "udd-mirror";
    ALTER DEFAULT PRIVILEGES FOR USER "public-udd-mirror" IN SCHEMA "public" GRANT SELECT ON TABLES TO "public-udd-mirror";
EOF

    trap trap_dropdb EXIT
    # Create a temporary database for our insertion of the new snapshot
    sudo -u postgres createdb -T template0 -E SQL_ASCII "$TMPDBNAME"
    echo CREATE EXTENSION debversion | sudo -u postgres psql -a "$TMPDBNAME"
    # https://github.com/paulproteus/public-udd-mirror/issues/21
    echo CREATE EXTENSION pg_trgm | sudo -u postgres psql -a "$TMPDBNAME"
    sudo -u postgres pg_restore -1 -v -d "$TMPDBNAME" "$UDD_FILENAME"
    echo "REVOKE CONNECT ON DATABASE ${TMPDBNAME} FROM public" | sudo -u postgres psql -a
    echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = '${TMPDBNAME}'" | sudo -u postgres psql -a

    echo
    echo "Created $TMPDBNAME."
    # Now drop the old database (if it exists) and, in a hurry, rename the tmp DB
    # into "udd" for public users.
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw udd ; then
        echo "REVOKE CONNECT ON DATABASE udd FROM public" | sudo -u postgres psql -a
        trap 'trap_dropdb GRANT' EXIT
        echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = 'udd'" | sudo -u postgres psql -a
        sleep 2 # wait 2 sec and do it again, it seems sometimes there are still open connections
        echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = 'udd'" | sudo -u postgres psql -a
        sudo -u postgres dropdb udd
    fi
    trap trap_dropdb EXIT  # if the old db is dropped, no use in restoring the grant if it fails
    # if the dropdb above went well, then do the rename (and please don't fail)
    echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = '${TMPDBNAME}'" | sudo -u postgres psql -a
    echo "ALTER DATABASE \"${TMPDBNAME}\" RENAME TO udd" | sudo -u postgres psql -a
    trap - EXIT
    echo "GRANT CONNECT ON DATABASE udd TO public" | sudo -u postgres psql -a

    # Now, set permissions nicely.
    echo 'GRANT select ON ALL TABLES IN SCHEMA public TO "public-udd-mirror";' | sudo -u postgres psql -a udd
    echo 'GRANT select ON ALL TABLES IN SCHEMA public TO "udd-mirror";' | sudo -u postgres psql -a udd

    echo
    echo "$(date -u): UDD mirror successfully updated!"
else
    printf '\nThe database is already up-to-date, doing nothing.\n'
fi

touch "$SUCCESS_STAMP"
echo "Releasing lock."
rm -vf "$LOCKFILE"
