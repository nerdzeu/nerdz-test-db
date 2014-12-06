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

cd $(dirname $0);

if [ $# -lt 2 ]; then
    echo "Usage: $0 existingRole db&username password"
    echo "Example: $0 postgres test_db"
    echo "    Existing role postgres will create a new database named test_db and a new user with the same name"
    exit -1
fi

DB_NAME=$1
DB_USER=$2
DB_PASS=$3

echo -n "Dropping if existing $DB_USER user and database... "

dropdb   -U $DB_NAME $DB_USER &> /dev/null || true
dropuser -U $DB_NAME $DB_USER &> /dev/null || true

echo "Done." ; echo

echo  "Creating database and user: $DB_USER (you'll be asked for password)..."

PGPASSWORD=$DB_PASS createuser -U $DB_NAME -S $DB_USER || exit -1
PGPASSWORD=$DB_PASS createdb -U $DB_NAME $DB_USER || exit -1

echo -n "Setting variables and privileges..."

PGPASSWORD=$DB_PASS psql $DB_USER $DB_NAME << EOF 1>/dev/null

GRANT ALL PRIVILEGES ON DATABASE $DB_USER TO $DB_USER\;
ALTER DATABASE $DB_USER SET timezone = 'UTC'\;
CREATE EXTENSION pgcrypto\;

EOF

echo "Done." ; echo
echo -n "Loading nerdz database schema and triggers into $DB_USER ... "

start_progress &
PROGRESS_PID=$!

tmp=$(mktemp)
cat testdb.sql | sed -e "s/OWNER TO test_db/OWNER TO $DB_USER/g" | sed -e "s/%%postgres%%/$DB_NAME/g" > $tmp
psql -U $DB_NAME $DB_USER < $tmp 1> /dev/null

disown $PROGRESS_PID
kill $PROGRESS_PID

echo "Done."

exit 0