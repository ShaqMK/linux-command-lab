#!/usr/bin/env bash
# etl_pipeline.sh — Day 4 ETL: validate, back up, clean and report on the lab CSVs.
# Explained in advanced/07-data-validation-and-etl-pipelines.md §31.
#
# Data contract (what the inputs must look like, or the run stops):
#   data/raw/students.csv  student_id,name,course,age          (4 columns, numeric IDs)
#   data/raw/payments.csv  payment_id,student_id,amount,status (4 columns, numeric IDs,
#                          status = completed|pending|failed, student_id must exist)
# The lab's current payments.csv (3 columns, P01/ST01 IDs) fails step 2 on purpose.

set -euo pipefail

cd "$(dirname "$0")/.."

RAW_DIR="data/raw"
PROCESSED_DIR="data/processed"
REPORT_DIR="reports"
LOG_DIR="logs"
BACKUP_DIR="backups"

mkdir -p "$PROCESSED_DIR" "$REPORT_DIR" \
         "$LOG_DIR" "$BACKUP_DIR"

log() {
    local level="$1"
    local message="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" \
        | tee -a "$LOG_DIR/etl.log"
}

log INFO "Pipeline started"

# 1. Validate source files
for file in "$RAW_DIR/students.csv" "$RAW_DIR/payments.csv"
do
    if [[ ! -s "$file" ]]; then
        log ERROR "Missing or empty file: $file"
        exit 1
    fi
done

# 2. Validate column counts
for file in "$RAW_DIR/students.csv" "$RAW_DIR/payments.csv"
do
    if ! awk -F',' 'NF != 4 {bad=1} END {exit bad}' "$file"; then
        log ERROR "Invalid column count in $file"
        exit 1
    fi
done

# 3. Validate headers
students_header=$(head -n 1 "$RAW_DIR/students.csv" | tr -d '[:space:]')
payments_header=$(head -n 1 "$RAW_DIR/payments.csv" | tr -d '[:space:]')

if [[ "$students_header" != "student_id,name,course,age" ]]; then
    log ERROR "Unexpected students header"
    exit 1
fi

if [[ "$payments_header" != "payment_id,student_id,amount,status" ]]; then
    log ERROR "Unexpected payments header"
    exit 1
fi

# 4. Create backup
tar -czf "$BACKUP_DIR/raw_$(date +%Y%m%d_%H%M%S).tar.gz" "$RAW_DIR"

log INFO "Backup created"

# 5. Create temporary processing directory
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/etl.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

# 6. Clean students
awk -F',' '
BEGIN {OFS=","}
NR == 1 {
    print "student_id","name","course","age"
    next
}
{
    for (i=1; i<=4; i++)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)

    if ($1 !~ /^[0-9]+$/ || $2 == "" ||
        $3 == "" || $4 !~ /^[0-9]+$/) {
        bad=1
        next
    }

    course=tolower($3)

    if (course=="data science")
        $3="Data Science"
    else if (course=="data engineering")
        $3="Data Engineering"

    print $1,$2,$3,$4
}
END {exit bad}
' "$RAW_DIR/students.csv" > "$TMP_DIR/students_clean.csv" || {
    log ERROR "Student transformation failed"
    exit 1
}

# 7. Clean and validate payments
awk -F',' '
BEGIN {OFS=","}
FNR==NR {
    if (FNR>1) students[$1]=1
    next
}
FNR==1 {
    print "payment_id","student_id","amount","status"
    next
}
{
    for (i=1; i<=4; i++)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)

    $4=tolower($4)

    if ($1 !~ /^[0-9]+$/ ||
        $2 !~ /^[0-9]+$/ ||
        $3 !~ /^[0-9]+([.][0-9]+)?$/ ||
        $4 !~ /^(completed|pending|failed)$/ ||
        !($2 in students)) {
        bad=1
        next
    }

    print $1,$2,$3,$4
}
END {exit bad}
' "$TMP_DIR/students_clean.csv" "$RAW_DIR/payments.csv" \
  > "$TMP_DIR/payments_clean.csv" || {
    log ERROR "Payment transformation failed"
    exit 1
}

# 8. Generate report
STUDENT_COUNT=$(awk 'END {print NR-1}' \
    "$TMP_DIR/students_clean.csv")

REVENUE=$(awk -F',' '
NR>1 && $4=="completed" {total+=$3}
END {printf "%.2f", total}
' "$TMP_DIR/payments_clean.csv")

{
    echo "DAY 4 ETL REPORT"
    echo "================"
    echo "Students processed: $STUDENT_COUNT"
    echo "Completed revenue: KSh $REVENUE"
    echo
    echo "Students by course:"

    awk -F',' '
    NR>1 {count[$3]++}
    END {
        for (course in count)
            print course, count[course]
    }
    ' "$TMP_DIR/students_clean.csv" | sort

} > "$TMP_DIR/etl_summary.txt"

# 9. Publish outputs
mv "$TMP_DIR/students_clean.csv" "$PROCESSED_DIR/students_clean.csv"
mv "$TMP_DIR/payments_clean.csv" "$PROCESSED_DIR/payments_clean.csv"
mv "$TMP_DIR/etl_summary.txt" "$REPORT_DIR/etl_summary.txt"

log INFO "Students processed: $STUDENT_COUNT"
log INFO "Completed revenue: KSh $REVENUE"
log INFO "Pipeline completed successfully"
