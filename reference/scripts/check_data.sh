#!/usr/bin/env bash
# check_data.sh — exit 0 if the students dataset exists, 1 if not.
# Explained in advanced/07-data-validation-and-etl-pipelines.md §30.
# Usage: ./scripts/check_data.sh && echo "safe to continue"

cd "$(dirname "$0")/.."

if [[ ! -f data/raw/students.csv ]]; then
  echo "ERROR: Students dataset missing" >&2
  exit 1
fi

echo "Dataset available"
exit 0
