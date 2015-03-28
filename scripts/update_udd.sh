#!/bin/bash
set -e
USER=$(whoami)
STARTING_CWD="/var/www"
LOGFILE="$STARTING_CWD/logs/log"

TMPDBNAME="udd_$(date -I)_$$"

if [ "$USER" != "public-udd-mirror" ] ; then
    echo "For sysadmin's sake, please run this script as the public-udd-mirror user"
    echo "This script has been called by $USER"
fi

exec &>> "$LOGFILE"

printf "\n\n"
echo "============================================================================="
printf "\n\n"
echo "Log started at $(date -u)"

UDD_URL=http://udd.debian.org/udd.sql.gz
UDD_FILENAME=udd.sql.gz
SUCCESS_STAMP="$STARTING_CWD/stamp"

# change directory into our happy land
mkdir -p "/tmp/$USER"
cd "/tmp/$USER"

# If we had no success stamp file, create one.
if [ ! -f "$SUCCESS_STAMP" ] ; then
    touch --date=1970-01-01 "$SUCCESS_STAMP"
fi

# Download the UDD dump, if it is newer
TZ=UTC wget -N "$UDD_URL"

# Check if it is newer than the last success stamp
if [ "$UDD_FILENAME" -nt "$SUCCESS_STAMP" ] ; then
    # Create a temporary database for our insertion of the new snapshot
    sudo -u postgres createdb -T template0 -E SQL_ASCII "$TMPDBNAME"
    echo CREATE EXTENSION debversion | sudo -u postgres psql "$TMPDBNAME"
    zcat "$UDD_FILENAME" | sudo -u postgres psql "$TMPDBNAME"
    echo "Created $TMPDBNAME."

    # Now drop the old database and, in a hurry, rename the tmp DB
    # into "udd" for public users.
    sudo -u postgres dropdb udd || true # OK if this fails b/c the Db
                                        # was missing.
    # Do the rename!
    echo "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE datname = 'udd'; ALTER DATABASE \"${TMPDBNAME}\" RENAME TO udd;" | sudo -u postgres psql

    # Now, set permissions nicely.
    for table in $(echo '\dt' | sudo -u postgres psql udd  | awk '{print $3}' | tail -n +3 ); do echo "GRANT  select ON $table TO "'"public-udd-mirror";' | sudo -u postgres psql udd ; done

    # Now, make sure we have the udd submodule properly
    cd "$STARTING_CWD"
    git submodule init
    git submodule update

    # Now, do a database export of our own.
    sudo -u postgres bash -x udd/scripts/dump-db.sh
else
    printf "\nThe database is already up-to-date, doing nothing.\n"
fi

touch "$SUCCESS_STAMP"
