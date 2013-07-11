#!/bin/bash
set -e
USER=$(whoami)
STARTING_CWD="/var/www"
LOGFILE="$STARTING_CWD/last-log"

exec &> "$LOGFILE"

echo -n "Log started at "
date
echo ''

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
wget -N "$UDD_URL"

# Check if it is newer than the last success stamp
if [ "$UDD_FILENAME" -nt "$SUCCESS_STAMP" ] ; then
    sudo -u postgres dropdb udd || true # OK if this fails

    sudo -u postgres createdb -T template0 -E SQL_ASCII udd
    echo CREATE EXTENSION debversion | sudo -u postgres psql udd
    zcat "$UDD_FILENAME" | sudo -u postgres psql udd
fi

touch "$SUCCESS_STAMP"
