#!/bin/bash
UDD_URL=http://udd.debian.org/udd.sql.gz
SUCCESS_STAMP=stamp

if [ ! -f "$SUCCESS_STAMP" ] ; then
    touch --date=1970-01-01 "$SUCCESS_STAMP"
fi

# change directory into our happy land
mkdir -p "/tmp/$USER"
cd "/tmp/$USER"

# Download the UDD dump, if it is newer
wget -N "$UDD_URL"

# Check if it is newer than the last success stamp
if [ "$UDD_URL" -nt "$SUCCESS_STAMP" ] ; then
    zcat udd.sql.gz | psql -U udd udd
fi

