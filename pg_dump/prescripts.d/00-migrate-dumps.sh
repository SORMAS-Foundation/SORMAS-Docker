#!/bin/sh

set -e

function MigrateDumps() {
    [ ! -d $1 ] && { mkdir $1; echo "Created $1"; } || { echo "$1 already created. Skipping migration... "; return; }
    for file in $(ls $2); do
        mv $file $1/
        echo "Moved $file to $1/$file"
    done
}

MigrateDumps /var/opt/db_dumps/db "/var/opt/db_dumps/*.sql.zst"
MigrateDumps /var/opt/db_dumps/documents "/var/opt/db_dumps/files.*.zst"
MigrateDumps /var/opt/db_dumps/configs "/var/opt/db_dumps/pg_dump.log"
