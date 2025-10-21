#!/bin/bash

# QUICK TEST - Single Document Test
# Created by: Tyson Siruno

WEBHOOK_URL="http://localhost:5678/webhook/upload-document"

echo "Quick Test: Sending single invoice..."

curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "INVOICE #QUICK-001\nBill To: Tyson Siruno\nTotal: $99.99",
    "uploadedBy": "Quick Test",
    "fileName": "quick_test.txt"
  }' | python3 -m json.tool

echo ""
echo "Check the response above for:"
echo "  ✓ success: true"
echo "  ✓ documentId"
echo "  ✓ processed.type: invoice"
echo "  ✓ storage.database: true"
echo "  ✓ storage.archive: true"
