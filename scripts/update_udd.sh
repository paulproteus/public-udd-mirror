#!/bin/bash
set -e
set -u
USER=$(whoami)
STARTING_CWD="/var/www/html"
LOGFILE="$STARTING_CWD/logs/log.txt"
LOCKFILE="/tmp/update_udd.$USER.lock"

if [ -f "$LOCKFILE" ]; then
    echo "Lockfile present, udd importer already running with PID $(cat "$LOCKFILE")" >&2
    exit 1
fi

TMPDBNAME="udd_$(date +%Y%m%d)_$$"

if [ "$USER" != "public-udd-mirror" ] ; then
    echo "For sysadmin's sake, please run this script as the public-udd-mirror user"
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
SUCCESS_STAMP="$STARTING_CWD/stamp"

# change directory into our happy land
mkdir -p "/tmp/$USER"
cd "/tmp/$USER"

# If we had no success stamp file, create one.
if [ ! -f "$SUCCESS_STAMP" ] ; then
    touch --date=1970-01-01 "$SUCCESS_STAMP"
fi

# Download the UDD dump, if it is newer
echo "Downloading udd.dump"
TZ=UTC wget -N --no-verbose "$UDD_URL"

# Check if it is newer than the last success stamp
if [ "$UDD_FILENAME" -nt "$SUCCESS_STAMP" ] ; then
    # Create a temporary database for our insertion of the new snapshot
    sudo -u postgres createdb -T template0 -E SQL_ASCII "$TMPDBNAME"
    echo CREATE EXTENSION debversion | sudo -u postgres psql -a "$TMPDBNAME"
    sudo -u postgres pg_restore -j 4 -v -d "$TMPDBNAME" "$UDD_FILENAME"
    echo "REVOKE CONNECT ON DATABASE ${TMPDBNAME} FROM public" | sudo -u postgres psql -a
    echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = '${TMPDBNAME}'" | sudo -u postgres psql -a

    echo
    echo "Created $TMPDBNAME."

    echo "Vacuuming..."
    echo "VACUUM" | sudo -u postgres psql -a "${TMPDBNAME}"

    # Now drop the old database and, in a hurry, rename the tmp DB
    # into "udd" for public users.
    echo "REVOKE CONNECT ON DATABASE udd FROM public" | sudo -u postgres psql -a
    echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = 'udd'" | sudo -u postgres psql -a
    sudo -u postgres dropdb udd || true # OK if this fails b/c the DB was missing or there still was open connections
    if [ "${PIPESTATUS[0]}" -ne 0 ] ; then
        echo "Failed at removing the old DB, exiting..."
        exit 0
    else
        # if the dropdb above went well, then do the rename (and please don't fail)
        echo "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid <> pg_backend_pid() AND datname = '${TMPDBNAME}'" | sudo -u postgres psql -a
        echo "ALTER DATABASE \"${TMPDBNAME}\" RENAME TO udd" | sudo -u postgres psql -a
        echo "GRANT CONNECT ON DATABASE udd TO public" | sudo -u postgres psql -a
    fi

    # Now, set permissions nicely.
    echo 'GRANT select ON ALL TABLES IN SCHEMA public TO "public-udd-mirror";' | sudo -u postgres psql -a udd
    echo 'GRANT select ON ALL TABLES IN SCHEMA public TO "udd-mirror";' | sudo -u postgres psql -a udd

    echo "Vacuuming + Analize..."
    echo "VACUUM ANALYZE" | sudo -u postgres psql -a udd

    echo
    echo "$(date -u): UDD mirror successfully updated!"
else
    printf '\nThe database is already up-to-date, doing nothing.\n'
fi

touch "$SUCCESS_STAMP"
rm -vf "$LOCKFILE"
