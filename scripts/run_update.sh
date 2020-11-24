#!/bin/sh

set -e
USER=$(whoami)
DIR=$(dirname "$0")

if [ "$USER" != "udd-mirror" ] ; then
    echo "This script has been called by $USER"
    echo "The updater script is thought to be run by the udd-mirror user."
    echo "Trying to sudo to that user..."
    sudo -u udd-mirror "$DIR/update_udd.sh"
else
    "$DIR/update_udd.sh"
fi
