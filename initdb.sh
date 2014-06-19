#!/usr/bin/env bash

start_progress () {
    while true; do
        echo -ne "|\b"
        sleep 0.1
        echo -ne "/\b"
        sleep 0.1
        echo -ne "-\b"
        sleep 0.1
    done
}

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

start_progress &
PROGRESS_PID=$!

tmp=$(mktemp)
cat testdb.sql | sed -e "s/OWNER TO test_db/OWNER TO $2/g" | sed -e "s/%%postgres%%/$1/g" > $tmp
psql -U "$1" "$2" < $tmp 1> /dev/null

disown $PROGRESS_PID
kill $PROGRESS_PID

echo "Done."

exit 0
