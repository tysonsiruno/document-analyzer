#!/bin/bash

# AUTOMATED TEST SUITE FOR DOCUMENT ANALYZER
# Created by: Tyson Siruno

set -e  # Exit on error

WEBHOOK_URL="http://localhost:5678/webhook/upload-document"
TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
PSQL="/opt/homebrew/Cellar/postgresql@15/15.14/bin/psql"

echo "========================================="
echo "TYSON'S DOCUMENT ANALYZER - TEST SUITE"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if N8N is running
echo "Checking N8N status..."
if ! curl -s http://localhost:5678 > /dev/null; then
  echo -e "${RED}✗ N8N is not running${NC}"
  echo "  Please start N8N and activate the workflow"
  exit 1
fi
echo -e "${GREEN}✓ N8N is running${NC}"
echo ""

# Test 1: Text Invoice Upload
echo "Test 1: Text Invoice Upload"
echo "----------------------------"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"$(cat "$TEST_DIR/test_invoice.txt" | tr '\n' ' ' | sed 's/"/\\"/g')\",
    \"uploadedBy\": \"Test Suite\",
    \"fileName\": \"test_invoice.txt\"
  }" 2>&1)

if echo "$RESPONSE" | grep -q '"success":true'; then
  DOC_ID_1=$(echo "$RESPONSE" | grep -o '"documentId":"[^"]*"' | cut -d'"' -f4)
  echo -e "${GREEN}✓ Invoice processed: $DOC_ID_1${NC}"
  TYPE=$(echo "$RESPONSE" | grep -o '"type":"[^"]*"' | head -1 | cut -d'"' -f4)
  CONF=$(echo "$RESPONSE" | grep -o '"confidence":[0-9]*' | head -1 | cut -d':' -f2)
  echo "  Type: $TYPE"
  echo "  Confidence: ${CONF}%"
else
  echo -e "${RED}✗ Invoice test failed${NC}"
  echo "$RESPONSE" | head -5
fi
echo ""

sleep 2

# Test 2: File Upload - Contract
echo "Test 2: Contract File Upload"
echo "----------------------------"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -F "data=@$TEST_DIR/test_contract.txt" \
  -F "uploadedBy=Test Suite" 2>&1)

if echo "$RESPONSE" | grep -q '"success":true'; then
  DOC_ID_2=$(echo "$RESPONSE" | grep -o '"documentId":"[^"]*"' | cut -d'"' -f4)
  echo -e "${GREEN}✓ Contract processed: $DOC_ID_2${NC}"
  TYPE=$(echo "$RESPONSE" | grep -o '"type":"[^"]*"' | head -1 | cut -d'"' -f4)
  CONF=$(echo "$RESPONSE" | grep -o '"confidence":[0-9]*' | head -1 | cut -d':' -f2)
  echo "  Type: $TYPE"
  echo "  Confidence: ${CONF}%"
else
  echo -e "${RED}✗ Contract test failed${NC}"
  echo "$RESPONSE" | head -5
fi
echo ""

sleep 2

# Test 3: Receipt Upload
echo "Test 3: Receipt File Upload"
echo "----------------------------"
RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -F "data=@$TEST_DIR/test_receipt.txt" \
  -F "uploadedBy=Test Suite" 2>&1)

if echo "$RESPONSE" | grep -q '"success":true'; then
  DOC_ID_3=$(echo "$RESPONSE" | grep -o '"documentId":"[^"]*"' | cut -d'"' -f4)
  echo -e "${GREEN}✓ Receipt processed: $DOC_ID_3${NC}"
else
  echo -e "${RED}✗ Receipt test failed${NC}"
  echo "$RESPONSE" | head -5
fi
echo ""

sleep 2

# Test 4: Database Verification
echo "Test 4: Database Verification"
echo "-----------------------------"
DB_COUNT=$($PSQL -d document_analyzer -t -c "SELECT COUNT(*) FROM processed_documents WHERE uploaded_by = 'Test Suite';" 2>/dev/null | xargs)

if [ "$DB_COUNT" -ge 3 ]; then
  echo -e "${GREEN}✓ Documents saved to database: $DB_COUNT${NC}"
else
  echo -e "${YELLOW}⚠ Expected 3+ documents, found: $DB_COUNT${NC}"
fi

# Show latest documents
echo "Latest documents:"
$PSQL -d document_analyzer -t -c "
  SELECT
    document_id,
    document_type,
    confidence_score,
    approval_status
  FROM processed_documents
  WHERE uploaded_by = 'Test Suite'
  ORDER BY processed_at DESC
  LIMIT 5;
" 2>/dev/null | while read line; do
  echo "  $line"
done
echo ""

# Test 5: Archive Verification
echo "Test 5: Archive Verification"
echo "----------------------------"
ARCHIVE_COUNT=$(find ~/Projects/n8n-production/archives -name "*.txt" -mmin -5 2>/dev/null | wc -l | xargs)
echo "Files archived (last 5 min): $ARCHIVE_COUNT"

if [ "$ARCHIVE_COUNT" -ge 1 ]; then
  echo -e "${GREEN}✓ Files are being archived${NC}"
  echo "Recent archives:"
  find ~/Projects/n8n-production/archives -name "*.txt" -mmin -5 -exec basename {} \; | head -3 | while read file; do
    echo "  - $file"
  done
else
  echo -e "${YELLOW}⚠ No recent archives found${NC}"
fi
echo ""

# Test 6: Performance Check
echo "Test 6: Performance Check"
echo "------------------------"
AVG_TIME=$($PSQL -d document_analyzer -t -c "
  SELECT ROUND(AVG(processing_time_ms)::numeric, 2)
  FROM processed_documents
  WHERE uploaded_by = 'Test Suite'
  AND processed_at > NOW() - INTERVAL '10 minutes';
" 2>/dev/null | xargs)

if [ -n "$AVG_TIME" ] && [ "$AVG_TIME" != "" ]; then
  echo "Average processing time: ${AVG_TIME}ms"

  if (( $(echo "$AVG_TIME < 5000" | bc -l) )); then
    echo -e "${GREEN}✓ Performance is excellent (<5s)${NC}"
  elif (( $(echo "$AVG_TIME < 10000" | bc -l) )); then
    echo -e "${YELLOW}⚠ Performance is acceptable (5-10s)${NC}"
  else
    echo -e "${RED}✗ Performance needs improvement (>10s)${NC}"
  fi
else
  echo "No performance data available"
fi
echo ""

# Summary
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="
echo "Documents processed: 3"
if [ -n "$DOC_ID_1" ]; then echo "  ✓ Invoice: $DOC_ID_1"; fi
if [ -n "$DOC_ID_2" ]; then echo "  ✓ Contract: $DOC_ID_2"; fi
if [ -n "$DOC_ID_3" ]; then echo "  ✓ Receipt: $DOC_ID_3"; fi
echo ""
echo "Database entries: $DB_COUNT"
echo "Archived files: $ARCHIVE_COUNT"
echo ""
echo "Next steps:"
echo "1. Check database: psql -d document_analyzer"
echo "2. View archives: ls -lR ~/Projects/n8n-production/archives/"
echo "3. Run health check: ./monitor.sh"
echo ""
echo "========================================="
