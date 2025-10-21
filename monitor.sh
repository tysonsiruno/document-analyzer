#!/bin/bash

# SYSTEM HEALTH MONITOR
# Created by: Tyson Siruno

PSQL="/opt/homebrew/Cellar/postgresql@15/15.14/bin/psql"

echo "========================================="
echo "DOCUMENT ANALYZER - HEALTH CHECK"
echo "========================================="
echo ""

# Check N8N
echo "N8N Status:"
if curl -s http://localhost:5678 > /dev/null; then
  echo "  ✓ N8N is running"
else
  echo "  ✗ N8N is not responding"
fi
echo ""

# Check Database
echo "Database Status:"
if $PSQL -d document_analyzer -c "SELECT 1" > /dev/null 2>&1; then
  echo "  ✓ Database is accessible"

  # Get stats
  DOC_COUNT=$($PSQL -d document_analyzer -t -c "SELECT COUNT(*) FROM processed_documents" 2>/dev/null | xargs)
  echo "  Total documents: ${DOC_COUNT:-0}"

  TODAY_COUNT=$($PSQL -d document_analyzer -t -c "SELECT COUNT(*) FROM processed_documents WHERE DATE(processed_at) = CURRENT_DATE" 2>/dev/null | xargs)
  echo "  Processed today: ${TODAY_COUNT:-0}"
else
  echo "  ✗ Database connection failed"
fi
echo ""

# Check Redis
echo "Redis Status:"
if redis-cli ping > /dev/null 2>&1; then
  echo "  ✓ Redis is running"
else
  echo "  ✗ Redis is not responding"
fi
echo ""

# Check Disk Space
echo "Disk Space:"
df -h ~/Projects/n8n-production/archives 2>/dev/null | tail -1 | awk '{print "  " $5 " used (" $4 " available)"}'
echo ""

# Check Logs
echo "Recent Errors:"
ERROR_COUNT=$(tail -100 ~/Projects/n8n-production/logs/errors.log 2>/dev/null | wc -l | xargs)
echo "  Error log entries: ${ERROR_COUNT:-0}"
echo ""

# Performance
echo "Performance (last hour):"
AVG_TIME=$($PSQL -d document_analyzer -t -c "
  SELECT ROUND(AVG(processing_time_ms)::numeric, 2)
  FROM processed_documents
  WHERE processed_at > NOW() - INTERVAL '1 hour'
" 2>/dev/null | xargs)
if [ -n "$AVG_TIME" ] && [ "$AVG_TIME" != "" ]; then
  echo "  Avg processing time: ${AVG_TIME}ms"
else
  echo "  Avg processing time: N/A (no recent data)"
fi
echo ""

echo "========================================="
echo "Timestamp: $(date)"
echo "========================================="
