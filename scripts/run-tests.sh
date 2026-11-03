#!/usr/bin/env bash
# Builds a throwaway database from sql/NN_*.sql, then runs every
# tests/NN_*_test.sql against it. Connection settings come from the standard
# libpq variables: PGHOST, PGPORT, PGUSER, PGPASSWORD.
#
#   PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres bash scripts/run-tests.sh
#
# TEST_DB names the database (default shop_test). KEEP_DB=1 keeps it afterwards.
set -euo pipefail
cd "$(dirname "$0")/.."

db="${TEST_DB:-shop_test}"
if [[ ! "$db" =~ ^[a-z_][a-z0-9_]*$ ]]; then
  echo "TEST_DB must be a plain lower-case identifier, got: $db" >&2
  exit 2
fi

# -X ignores ~/.psqlrc, -q hides command tags, ON_ERROR_STOP turns the first
# failed statement into a non-zero exit code.
psql_cmd=(psql -X -q -v ON_ERROR_STOP=1)

drop_db() {
  "${psql_cmd[@]}" -d postgres -c "DROP DATABASE IF EXISTS ${db} WITH (FORCE)"
}

echo "== create database ${db}"
drop_db
"${psql_cmd[@]}" -d postgres -c "CREATE DATABASE ${db}"
[[ -n "${KEEP_DB:-}" ]] || trap drop_db EXIT

for file in sql/[0-9][0-9]_*.sql; do
  echo "== apply ${file}"
  "${psql_cmd[@]}" -d "$db" -f "$file"
done

status=0
for test in tests/[0-9][0-9]_*_test.sql; do
  echo "== ${test}"
  # helpers.sql and the test share one session, so pg_temp helpers are visible.
  # Query results go to /dev/null; the NOTICE lines on stderr are the report.
  if ! "${psql_cmd[@]}" -d "$db" -o /dev/null -f tests/helpers.sql -f "$test"; then
    status=1
  fi
done

if [[ "$status" -eq 0 ]]; then echo "All SQL tests passed."; else echo "Some SQL tests failed." >&2; fi
exit "$status"
