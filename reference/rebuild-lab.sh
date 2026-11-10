#!/usr/bin/env bash
# rebuild-lab.sh — recreate the practice workspace used throughout the lessons.
#
# Usage:
#   bash reference/rebuild-lab.sh                 # builds ~/linux-command-lab
#   LAB_DIR=~/sandbox bash reference/rebuild-lab.sh
#
# Safe to re-run: every file is overwritten with `>`, directories use `mkdir -p`.
set -euo pipefail

LAB_DIR="${LAB_DIR:-$HOME/linux-command-lab}"

mkdir -p "$LAB_DIR" && cd "$LAB_DIR"
[ -d "scripts " ] && mv "scripts " scripts        # repair the trailing-space folder if present (§7)
mkdir -p backups config data/{raw,processed,archived} logs reports scripts
rm -f backups/analyze.sh backups/backup.sh

cat << 'EOF' > data/raw/students.csv
student_id,name,course,age
1,John,Data Science,23
2,Mary,Data Engineering,25
3,Mike,Data Science,30
4,Alice,Data Science,23
5,Bob,Data Engineering,28
6,Sarah,Machine Learning,24
EOF

cat << 'EOF' > data/raw/payments.csv
payment_id,student_id,amount
P01,1,10000
P02,2,5000
P03,3,3000
P04,4,7000
EOF

cat << 'EOF' > config/app.conf
# Application configuration
APP_NAME=linux-command-lab
ENVIRONMENT=development
DATA_DIR=data/raw
BACKUP_DIR=backups
LOG_FILE=logs/application.log
LOG_LEVEL=INFO
EOF

cat << 'EOF' > logs/application.log
2026-11-09 08:00:01 INFO  Application started
2026-11-09 08:00:05 INFO  Loaded students.csv (6 rows)
2026-11-09 08:00:06 WARN  Inconsistent course name: "Data science"
2026-11-09 08:01:12 ERROR Failed to open scripts/analyze.sh: No such file or directory
2026-11-09 08:02:30 INFO  Backup completed
EOF

cat << 'EOF' > scripts/backup.sh
#!/usr/bin/env bash
# Backs up data/raw into a timestamped tar.gz in backups/
set -euo pipefail

source config/app.conf

timestamp=$(date +%Y%m%d_%H%M%S)
archive="${BACKUP_DIR}/raw_${timestamp}.tar.gz"

tar -czf "$archive" "$DATA_DIR"
echo "$(date '+%F %T') INFO  Backup created: $archive" >> "$LOG_FILE"
echo "Backup created: $archive"
EOF

cat << 'EOF' > scripts/analyze.sh
#!/usr/bin/env bash
# Prints student counts per course and total payments
set -euo pipefail

echo "== Students per course =="
tail -n +2 data/raw/students.csv | cut -d',' -f3 | sort | uniq -c | sort -rn

echo
echo "== Total payments =="
awk -F',' 'NR > 1 { total += $3 } END { print total }' data/raw/payments.csv
EOF

chmod +x scripts/*.sh

echo "Lab rebuilt in: $LAB_DIR"
if command -v tree > /dev/null; then tree; else ls -R; fi
echo
echo "Name check (every line should end in a bare \$):"
ls | cat -vet
