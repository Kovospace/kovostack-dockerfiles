#!/bin/sh
set -e

# The SQLite adapter auto-syncs the schema on first init (push mode), so there
# is no separate migration step — just start the standalone server.
echo "Starting NSR Soundsystem..."
exec node server.js