#!/bin/bash

# AUTOMATED BACKUP SCRIPT
# Created by: Tyson Siruno

BACKUP_DIR="/Users/tysonsiruno/Projects/n8n-production/backups"
DATE=$(date +%Y%m%d_%H%M%S)
PSQL="/opt/homebrew/Cellar/postgresql@15/15.14/bin/psql"
PG_DUMP="/opt/homebrew/Cellar/postgresql@15/15.14/bin/pg_dump"

mkdir -p "$BACKUP_DIR"

echo "Starting backup: $DATE"

# Backup database
echo "Backing up database..."
$PG_DUMP document_analyzer | gzip > "$BACKUP_DIR/db_backup_$DATE.sql.gz"

if [ $? -eq 0 ]; then
  echo "✓ Database backup created: db_backup_$DATE.sql.gz"
else
  echo "✗ Database backup failed"
fi

# Backup N8N workflow
echo "Backing up N8N workflow..."
if [ -f ~/Desktop/TYSON_DOC_ANALYZER_3000.json ]; then
  cp ~/Desktop/TYSON_DOC_ANALYZER_3000.json "$BACKUP_DIR/workflow_$DATE.json"
  echo "✓ Workflow backup created: workflow_$DATE.json"
fi

# Backup environment config (without sensitive data)
echo "Backing up configuration..."
if [ -f .env ]; then
  # Create sanitized version
  grep -v "PASSWORD\|API_KEY\|SECRET\|WEBHOOK" .env > "$BACKUP_DIR/env_$DATE.txt" 2>/dev/null
  echo "✓ Config backup created (sanitized): env_$DATE.txt"
fi

# Backup recent archives (last 7 days)
echo "Backing up recent archives..."
find archives/ -type f -mtime -7 2>/dev/null | tar -czf "$BACKUP_DIR/archives_$DATE.tar.gz" -T - 2>/dev/null
if [ $? -eq 0 ]; then
  echo "✓ Archives backup created: archives_$DATE.tar.gz"
fi

# Cleanup old backups (keep last 30 days)
echo "Cleaning up old backups (keeping last 30 days)..."
find "$BACKUP_DIR" -name "*.gz" -mtime +30 -delete 2>/dev/null
find "$BACKUP_DIR" -name "*.json" -mtime +30 -delete 2>/dev/null
find "$BACKUP_DIR" -name "*.txt" -mtime +30 -delete 2>/dev/null

echo ""
echo "Backup complete: $BACKUP_DIR"
echo "Total backup size: $(du -sh $BACKUP_DIR | cut -f1)"
echo "Files in backup directory: $(ls -1 $BACKUP_DIR | wc -l | xargs)"
