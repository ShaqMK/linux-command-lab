#!/usr/bin/env bash
# payments_pipeline.sh — validate payments.csv, set bad rows aside, report on the good ones.
# Explained in advanced/07-data-validation-and-etl-pipelines.md §32.
#
# Expects data/raw/payments.csv with 3 columns: payment_id,student_id,amount
# (IDs like P01 and ST01; ", " or "," separators both work).
#
# Change from the session version: amount comparisons use `$3 + 0` so they are
# numeric. gsub() turns a field into a string, and "7000" > 50000 compared as text
# is true (see §32).

set -euo pipefail

cd "$(dirname "$0")/.."

RAW_FILE="data/raw/payments.csv"
CLEAN_FILE="data/processed/payments_clean.csv"
REPORT_FILE="reports/payments_report.txt"
LOG_FILE="logs/payments.log"
ERROR_FILE="logs/errors.log"   # tip: a dedicated file (e.g. logs/payments_rejects.log) avoids wiping older entries

mkdir -p data/processed reports logs
: > "$ERROR_FILE"  # Clear old error log before each run

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "$LOG_FILE"
}

log "INFO" "Starting student payments pipeline..."

# 1. EXTRACT: Verify file exists and is not empty
if [[ ! -s "$RAW_FILE" ]]; then
  log "ERROR" "Missing or empty file: $RAW_FILE"
  exit 1
fi

# 2. TRANSFORM & VALIDATE: Clean spaces, separate bad rows, save valid records
awk -F',' -v err_file="$ERROR_FILE" '
BEGIN { OFS="," }
NR == 1 {
  print "payment_id","student_id","amount"
  next
}
{
  # Trim leading and trailing whitespace on all fields
  for (i=1; i<=NF; i++) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
  }

  # Rule 1: Check column count
  if (NF != 3) {
    print "Line " NR " [Wrong column count]: " $0 >> err_file
    next
  }

  # Rule 2: Validate payment_id format (must be P followed by digits, e.g. P01)
  if ($1 !~ /^P[0-9]+$/) {
    print "Line " NR " [Invalid payment_id]: " $0 >> err_file
    next
  }

  # Rule 3: Check for duplicate payment_id
  if ($1 in seen_payment) {
    print "Line " NR " [Duplicate payment_id]: " $0 >> err_file
    next
  }
  seen_payment[$1] = 1

  # Rule 4: Validate student_id format (must be ST followed by digits, e.g. ST01)
  if ($2 !~ /^ST[0-9]+$/) {
    print "Line " NR " [Invalid student_id]: " $0 >> err_file
    next
  }

  # Rule 5: Validate amount is a positive number (> 0)
  if ($3 !~ /^[0-9]+([.][0-9]+)?$/ || $3 + 0 <= 0) {
    print "Line " NR " [Invalid or negative amount]: " $0 >> err_file
    next
  }

  # Optional warning flag for unusually high amounts (> 50,000)
  if ($3 + 0 > 50000) {
    print "Line " NR " [WARNING - High amount > 50000]: " $0 >> err_file
  }

  print $1, $2, $3
}
' "$RAW_FILE" > "$CLEAN_FILE"

# 3. REPORT: Summarize valid records and rejected errors
VALID_COUNT=$(awk 'END {print NR-1}' "$CLEAN_FILE")
ERROR_COUNT=$(grep -vc "WARNING" "$ERROR_FILE" || true)
TOTAL_REV=$(awk -F',' 'NR>1 {sum+=$3} END {printf "%.2f", sum}' "$CLEAN_FILE")
AVG_REV=$(awk -F',' 'NR>1 {sum+=$3; n++} END {if (n>0) printf "%.2f", sum/n; else print "0.00"}' "$CLEAN_FILE")

{
  echo "STUDENT PAYMENTS SUMMARY"
  echo "========================"
  echo "Valid transactions   : $VALID_COUNT"
  echo "Rejected records     : $ERROR_COUNT"
  echo "Total valid revenue  : KSh $TOTAL_REV"
  echo "Average payment      : KSh $AVG_REV"
} > "$REPORT_FILE"

cat "$REPORT_FILE"

if [[ -s "$ERROR_FILE" ]]; then
  log "WARN" "Issues logged in $ERROR_FILE:"
  cat "$ERROR_FILE"
fi

log "INFO" "Pipeline finished. Clean data saved to $CLEAN_FILE"
