#!/usr/bin/env bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 existingRole db&username"
    echo "Example: $0 postgres test_db"
    echo "    Existing role postgres will create a new database named test_db and a new user with the same name"
    exit -1
fi

echo -n "Dropping if existing $2 user and database... "

dropdb   -U "$1" "$2" &> /dev/null || true
dropuser -U "$1" "$2" &> /dev/null || true

echo "Done." ; echo

echo  "Creating database and user: $2 (you'll be asked for password)..."

createuser -P -U "$1" -S "$2" || exit -1
createdb -U "$1" "$2" || exit -1

echo -n "Setting variables and privileges..."

psql "$2" "$1" << EOF 1>/dev/null

GRANT ALL PRIVILEGES ON DATABASE $2 TO $2\;
ALTER DATABASE $2 SET timezone = 'UTC'\;
CREATE EXTENSION pgcrypto\;

EOF

echo "Done." ; echo
echo -n "Loading nerdz database schema and triggers into $2 ... "

psql -U "$1" "$2" < testdb.sql 1> /dev/null

echo "Done."
