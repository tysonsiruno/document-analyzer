#!/bin/bash

# LOAD TEST - Process Multiple Documents
# Created by: Tyson Siruno

WEBHOOK_URL="http://localhost:5678/webhook/upload-document"
NUM_DOCS=${1:-50}  # Default to 50 documents

echo "========================================="
echo "LOAD TEST: Processing $NUM_DOCS documents"
echo "========================================="
echo ""

START_TIME=$(date +%s)

echo "Sending documents in batches of 10..."

for i in $(seq 1 $NUM_DOCS); do
  # Generate random document type
  TYPES=("invoice" "contract" "receipt")
  TYPE=${TYPES[$((RANDOM % 3))]}

  # Generate test data
  if [ "$TYPE" = "invoice" ]; then
    TEXT="INVOICE #LOAD-$i\\nBill To: Test User\\nTotal: \$$(($i * 10)).00"
  elif [ "$TYPE" = "contract" ]; then
    TEXT="SERVICE AGREEMENT #LOAD-$i\\nParty A: Test Corp\\nDuration: $i months"
  else
    TEXT="RECEIPT #LOAD-$i\\nCoffee: \$5.00\\nTotal: \$$(($i + 5)).00"
  fi

  # Send document in background
  curl -s -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$TEXT\",\"uploadedBy\":\"Load Test\",\"fileName\":\"load_test_$i.txt\"}" \
    > /dev/null 2>&1 &

  # Show progress every 10 documents
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Sent $i documents..."
    wait  # Wait for batch to complete
    sleep 1  # Brief pause between batches
  fi
done

wait  # Wait for all to complete

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "========================================="
echo "LOAD TEST COMPLETE"
echo "========================================="
echo "Documents sent: $NUM_DOCS"
echo "Time taken: ${DURATION}s"

if [ $DURATION -gt 0 ]; then
  RATE=$((NUM_DOCS / DURATION))
  echo "Processing rate: ~${RATE} docs/second"
fi

echo ""
echo "Checking database..."
sleep 2

# Check database
PSQL="/opt/homebrew/Cellar/postgresql@15/15.14/bin/psql"
COUNT=$($PSQL -d document_analyzer -t -c "SELECT COUNT(*) FROM processed_documents WHERE uploaded_by = 'Load Test';" 2>/dev/null | xargs)

echo "Documents in database: $COUNT"

if [ "$COUNT" -ge "$((NUM_DOCS - 5))" ]; then
  echo "✓ Load test successful (95%+ saved)"
else
  echo "⚠ Some documents may have failed"
fi

# Performance stats
echo ""
echo "Performance statistics:"
AVG_TIME=$($PSQL -d document_analyzer -t -c "
  SELECT ROUND(AVG(processing_time_ms)::numeric, 2)
  FROM processed_documents
  WHERE uploaded_by = 'Load Test';
" 2>/dev/null | xargs)

MAX_TIME=$($PSQL -d document_analyzer -t -c "
  SELECT MAX(processing_time_ms)
  FROM processed_documents
  WHERE uploaded_by = 'Load Test';
" 2>/dev/null | xargs)

MIN_TIME=$($PSQL -d document_analyzer -t -c "
  SELECT MIN(processing_time_ms)
  FROM processed_documents
  WHERE uploaded_by = 'Load Test';
" 2>/dev/null | xargs)

echo "  Average: ${AVG_TIME}ms"
echo "  Minimum: ${MIN_TIME}ms"
echo "  Maximum: ${MAX_TIME}ms"

echo ""
echo "Cleanup: Run this to remove test data:"
echo "  psql -d document_analyzer -c \"DELETE FROM processed_documents WHERE uploaded_by = 'Load Test';\""
echo "========================================="
