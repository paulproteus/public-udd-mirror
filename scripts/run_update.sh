#!/bin/sh

set -e
USER=$(whoami)

if [ "$USER" != "public-udd-mirror" ] ; then
    echo "This script has been called by $USER"
    echo "The updater script is thought to be run by the public-udd-mirror user."
    echo "Trying to sudo to that user..."
    sudo -u public-udd-mirror /var/www/scripts/update_udd.sh
else
    /var/www/scripts/update_udd.sh
fi
