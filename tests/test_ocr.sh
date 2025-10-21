#!/bin/bash

# OCR TESTING SCRIPT
# Tests PDF and image processing with OCR.space API
# Created by: Tyson Siruno

WEBHOOK_URL="http://localhost:5678/webhook/upload-document"
TEST_DIR="$(dirname "$0")"

echo "================================"
echo "OCR PROCESSING TEST"
echo "================================"
echo ""
echo "Testing OCR.space integration..."
echo ""

# Test 1: Simulate PDF upload with base64 encoding
echo "📄 Test 1: PDF Upload Simulation"
echo "--------------------------------"

# Create a simple text file to simulate PDF upload
echo "INVOICE #PDF-001
Bill To: Tyson Siruno
Date: October 20, 2025
Amount: $500.00
Description: OCR Testing Services" > "$TEST_DIR/test_pdf_content.txt"

# Encode to base64 (simulating PDF)
PDF_BASE64=$(base64 < "$TEST_DIR/test_pdf_content.txt")

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"[FILE UPLOADED - OCR PROCESSING NEEDED]\",
    \"uploadedBy\": \"OCR Test\",
    \"fileName\": \"test_invoice.pdf\",
    \"fileType\": \"application/pdf\",
    \"binaryData\": \"$PDF_BASE64\"
  }" | python3 -m json.tool

echo ""
echo "✓ PDF test complete"
echo ""

# Test 2: Test with image simulation
echo "🖼️  Test 2: Image Upload Simulation"
echo "--------------------------------"

echo "RECEIPT
Starbucks Coffee
Grande Latte: $5.25
Total: $5.25
Tyson's Fuel!" > "$TEST_DIR/test_image_content.txt"

IMAGE_BASE64=$(base64 < "$TEST_DIR/test_image_content.txt")

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": \"[FILE UPLOADED - OCR PROCESSING NEEDED]\",
    \"uploadedBy\": \"OCR Test\",
    \"fileName\": \"receipt_scan.jpg\",
    \"fileType\": \"image/jpeg\",
    \"binaryData\": \"$IMAGE_BASE64\"
  }" | python3 -m json.tool

echo ""
echo "✓ Image test complete"
echo ""

# Clean up test files
rm -f "$TEST_DIR/test_pdf_content.txt"
rm -f "$TEST_DIR/test_image_content.txt"

echo "================================"
echo "✅ OCR TESTING COMPLETE!"
echo "================================"
echo ""
echo "Check the responses above for:"
echo "  ✓ ocr.used: true"
echo "  ✓ ocr.engine: 'OCR.space Engine 2'"
echo "  ✓ Extracted text in rawText field"
echo ""
echo "📊 Database check:"
echo "psql -d document_analyzer -c \"SELECT document_id, file_name, (metadata->>'ocr_used')::boolean FROM processed_documents WHERE uploaded_by = 'OCR Test' ORDER BY created_at DESC LIMIT 5;\""
echo ""
echo "📁 Archive check:"
echo "ls -lh ~/Projects/n8n-production/archives/*/approved/*/*"
echo ""

# Instructions for real PDF/image testing
echo "================================"
echo "🔍 TESTING WITH REAL FILES"
echo "================================"
echo ""
echo "To test with actual PDF or image files:"
echo ""
echo "1. Upload a PDF:"
echo "   curl -X POST $WEBHOOK_URL \\"
echo "     -F 'data=@/path/to/your/invoice.pdf' \\"
echo "     -F 'uploadedBy=Tyson'"
echo ""
echo "2. Upload an image:"
echo "   curl -X POST $WEBHOOK_URL \\"
echo "     -F 'data=@/path/to/your/receipt.jpg' \\"
echo "     -F 'uploadedBy=Tyson'"
echo ""
echo "3. Check the result in N8N executions"
echo "   Open: http://localhost:5678"
echo "   Click: Executions tab"
echo ""
echo "Free tier limit: 500 OCR requests/day"
echo ""
