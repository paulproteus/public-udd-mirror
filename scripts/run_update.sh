#!/bin/sh

if [ "$USER" != "public-udd-mirror" ] ; then
    echo "The updater script is not run as the public-udd-mirror user."
    echo "Trying to sudo to that user..."
    sudo su -c /var/www/scripts/update_udd.sh public-udd-mirror
fi
