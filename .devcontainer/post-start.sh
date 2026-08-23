#!/usr/bin/env bash
set -euo pipefail

bundle check || bundle install

# Load dev secrets from .env (if present) into this shell and its children
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi
