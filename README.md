nerdz-test-db
=============

NERDZ test database.

Use it for a quick develop of a nerdz-based application (plugins and so on). Add it as a submodule of your project if you want.

Setup
=====

Run `./initdb.sh existingRole db&username password`
Example: `./initdb.sh postgres test_db pass`

Existing role postgres (superuser) will create a new database named test_db and a new user with the same name, with the password "pass"

Testing
=======
If you use this database to run a local copy of [NERDZ](https://github.com/nerdzeu/nerdz.eu), you can login as "admin" user using
- Username: admin
- Password: adminadmin
