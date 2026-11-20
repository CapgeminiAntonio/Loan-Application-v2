#!/usr/bin/env sh
set -e

export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${PGUSER:-postgres}"

dropdb --if-exists loans
createdb --owner=loans loans
echo "Database reset complete. Start the backend with the dev profile to apply migrations and seed demo data."
