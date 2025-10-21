# 🛡️ ERROR HANDLING & RECOVERY GUIDE

**System:** Document Analyzer 3000
**Version:** 3000.3.0
**Created by:** Tyson Siruno

---

## 🎯 Error Handling Features

### **1. Automatic Retries with Exponential Backoff**

**Database Operations:**
- Max retries: 3 attempts
- Delays: 1s, 2s, 3s (exponential backoff)
- Automatic connection recovery
- Transaction rollback on failure

**File Archiving:**
- Max retries: 3 attempts
- Delays: 1s, 2s, 3s
- Directory creation on retry
- Partial file cleanup

### **2. Comprehensive Error Logging**

**File-Based Logging:**
- Location: `~/Projects/n8n-production/logs/errors.log`
- Format: JSON (one error per line)
- Includes: timestamp, document ID, error message, stack trace
- Automatic append (no file size limit)

**Database Logging:**
- Table: `failed_documents`
- Stores: document ID, failure reason, retry count, full error, raw data
- Queryable for analysis
- Preserves original document data for reprocessing

### **3. Dead Letter Queue**

Failed documents are saved to `failed_documents` table with:
- Original document data (for reprocessing)
- Failure reason
- Number of retry attempts
- Complete error stack trace
- Timestamp of failure
- Resolution status (for tracking fixes)

### **4. Graceful Degradation**

**When database fails:**
- Workflow continues
- File still archived
- Error logged to file
- Partial response returned

**When archiving fails:**
- Workflow continues
- Data still saved to database
- Error logged
- Partial response returned

**When both fail:**
- Error logged to file
- Response indicates failure
- Original data preserved in error log

### **5. Error Response Format**

**Success Response:**
```json
{
  "success": true,
  "documentId": "DOC-123",
  "processed": {
    "type": "invoice",
    "confidence": 95
  },
  "storage": {
    "database": true,
    "archive": true
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "documentId": "DOC-123",
  "errors": [
    {
      "component": "database",
      "message": "Connection refused",
      "retryCount": 3
    }
  ],
  "partialResults": {
    "classification": {...},
    "confidence": 85
  }
}
```

---

## 📊 Error Categories

### **Recoverable Errors** (Auto-retry)
- Database connection timeouts
- File system temporary locks
- Network interruptions
- Disk space warnings (if recoverable)

### **Non-Recoverable Errors** (Log and fail)
- Invalid SQL syntax
- File permission denied (persistent)
- Out of disk space
- Corrupt file data

---

## 🔍 Monitoring Errors

### **Check Error Log:**
```bash
# View recent errors
tail -f ~/Projects/n8n-production/logs/errors.log

# Parse errors with jq
tail -20 ~/Projects/n8n-production/logs/errors.log | jq '.'

# Count errors by type
grep -o '"operation":"[^"]*"' ~/Projects/n8n-production/logs/errors.log | sort | uniq -c
```

### **Query Failed Documents:**
```sql
-- View all unresolved failures
SELECT * FROM recent_failures;

-- Count failures by reason
SELECT
  failure_reason,
  COUNT(*) as count
FROM failed_documents
WHERE resolved = FALSE
GROUP BY failure_reason
ORDER BY count DESC;

-- Get latest failures
SELECT
  document_id,
  failure_reason,
  retry_count,
  failed_at
FROM failed_documents
WHERE resolved = FALSE
ORDER BY failed_at DESC
LIMIT 10;
```

### **Check Audit Log:**
```sql
-- View processing failures
SELECT * FROM audit_log
WHERE action = 'PROCESSING_FAILED'
ORDER BY created_at DESC
LIMIT 20;

-- Count failures by user
SELECT
  user_name,
  COUNT(*) as failure_count
FROM audit_log
WHERE action = 'PROCESSING_FAILED'
GROUP BY user_name;
```

---

## 🔧 Recovery Procedures

### **Reprocess Failed Documents**

**Step 1: Identify failures**
```sql
SELECT
  id,
  document_id,
  failure_reason,
  raw_data
FROM failed_documents
WHERE resolved = FALSE
LIMIT 10;
```

**Step 2: Extract original data**
```sql
SELECT raw_data FROM failed_documents WHERE id = 123;
```

**Step 3: Resubmit via webhook**
```bash
# Copy the raw_data JSON and resubmit
curl -X POST http://localhost:5678/webhook/upload-document \
  -H "Content-Type: application/json" \
  -d '<paste raw_data here>'
```

**Step 4: Mark as resolved**
```sql
UPDATE failed_documents
SET resolved = TRUE
WHERE id = 123;
```

### **Bulk Reprocessing Script**

```bash
#!/bin/bash
# Location: ~/Projects/n8n-production/scripts/reprocess_failures.sh

PSQL="/opt/homebrew/Cellar/postgresql@15/15.14/bin/psql"
WEBHOOK_URL="http://localhost:5678/webhook/upload-document"

# Get unresolved failures
$PSQL -d document_analyzer -t -c "
  SELECT raw_data FROM failed_documents WHERE resolved = FALSE LIMIT 10;
" | while read -r raw_data; do
  if [ -n "$raw_data" ]; then
    echo "Reprocessing document..."
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "$raw_data"
    sleep 1  # Rate limiting
  fi
done

echo "Reprocessing complete"
```

---

## 📈 Error Rate Monitoring

### **Calculate Error Rate**

```sql
-- Last 24 hours
SELECT
  COUNT(*) FILTER (WHERE al.action = 'DOCUMENT_PROCESSED') as successful,
  COUNT(*) FILTER (WHERE al.action = 'PROCESSING_FAILED') as failed,
  ROUND(
    COUNT(*) FILTER (WHERE al.action = 'PROCESSING_FAILED')::numeric /
    NULLIF(COUNT(*), 0) * 100,
    2
  ) as error_rate_percent
FROM audit_log al
WHERE created_at > NOW() - INTERVAL '24 hours';
```

### **Error Trend Analysis**

```sql
-- Errors per hour (last 24 hours)
SELECT
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) as error_count
FROM audit_log
WHERE action = 'PROCESSING_FAILED'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;
```

---

## 🚨 Alert Thresholds

### **Recommended Alerts:**

1. **High Error Rate**
   - Threshold: >5% failure rate
   - Action: Investigate immediately

2. **Repeated Failures**
   - Threshold: Same error 10+ times
   - Action: Fix root cause

3. **Database Connection Issues**
   - Threshold: 3+ connection failures in 1 hour
   - Action: Check database service

4. **Disk Space Low**
   - Threshold: <10% available
   - Action: Clean old archives

---

## 🛠️ Troubleshooting Common Errors

### **Error: "Connection refused"**
**Cause:** Database not running
**Fix:**
```bash
brew services restart postgresql@15
```

### **Error: "ENOSPC: no space left on device"**
**Cause:** Disk full
**Fix:**
```bash
# Clean old archives
find ~/Projects/n8n-production/archives -name "*.txt" -mtime +30 -delete

# Clean old backups
find ~/Projects/n8n-production/backups -name "*.gz" -mtime +30 -delete
```

### **Error: "EACCES: permission denied"**
**Cause:** File permissions
**Fix:**
```bash
chmod -R 755 ~/Projects/n8n-production/archives
```

### **Error: "Duplicate key value violates unique constraint"**
**Cause:** Document ID already exists
**Fix:** This is handled automatically by ON CONFLICT clause

---

## 📋 Error Handling Checklist

### **Daily Monitoring:**
- [ ] Check error log for new entries
- [ ] Review failed_documents count
- [ ] Verify error rate < 5%
- [ ] Check disk space

### **Weekly Maintenance:**
- [ ] Reprocess failed documents
- [ ] Clean old error logs
- [ ] Review error trends
- [ ] Update alert thresholds

### **Monthly Review:**
- [ ] Analyze error patterns
- [ ] Identify recurring issues
- [ ] Optimize retry logic
- [ ] Update documentation

---

## 🎯 Best Practices

### **For Developers:**
1. Always wrap external calls in try-catch
2. Log errors with context (document ID, timestamp)
3. Implement retry logic for transient failures
4. Return meaningful error messages
5. Preserve original data for recovery

### **For Operations:**
1. Monitor error logs regularly
2. Set up alerts for high error rates
3. Keep backups of failed_documents table
4. Test recovery procedures quarterly
5. Document custom fixes

---

## 📊 Error Metrics Dashboard

### **Key Metrics to Track:**

```sql
-- Error Rate (Last 24h)
SELECT
  ROUND(
    (SELECT COUNT(*) FROM failed_documents WHERE failed_at > NOW() - INTERVAL '24 hours')::numeric /
    NULLIF((SELECT COUNT(*) FROM processed_documents WHERE processed_at > NOW() - INTERVAL '24 hours'), 0) * 100,
    2
  ) as error_rate_24h;

-- Average Retry Count
SELECT
  ROUND(AVG(retry_count), 2) as avg_retries
FROM failed_documents
WHERE failed_at > NOW() - INTERVAL '7 days';

-- Most Common Errors
SELECT
  failure_reason,
  COUNT(*) as occurrences
FROM failed_documents
WHERE failed_at > NOW() - INTERVAL '7 days'
GROUP BY failure_reason
ORDER BY occurrences DESC
LIMIT 5;

-- Recovery Success Rate
SELECT
  COUNT(*) FILTER (WHERE resolved = TRUE) as resolved,
  COUNT(*) FILTER (WHERE resolved = FALSE) as unresolved,
  ROUND(
    COUNT(*) FILTER (WHERE resolved = TRUE)::numeric /
    NULLIF(COUNT(*), 0) * 100,
    2
  ) as recovery_rate_percent
FROM failed_documents;
```

---

## 🔐 Security Considerations

**Error Logging:**
- ✅ Errors logged to secure location
- ✅ No sensitive data in error messages
- ✅ Stack traces don't expose credentials
- ✅ File permissions restrict access

**Failed Documents:**
- ✅ Raw data stored securely in database
- ✅ Access controlled by database permissions
- ✅ PII encrypted at rest
- ✅ Audit trail of who accessed failed records

---

## 📚 Additional Resources

**Files:**
- Error log: `~/Projects/n8n-production/logs/errors.log`
- Monitor script: `~/Projects/n8n-production/monitor.sh`
- Database schema: `~/Projects/n8n-production/schema.sql`

**Queries:**
```sql
-- View error-related tables
\d failed_documents
\d audit_log

-- View error-related views
SELECT * FROM recent_failures;
```

**Test Error Handling:**
```bash
# Test with invalid data
curl -X POST http://localhost:5678/webhook/upload-document \
  -H "Content-Type: application/json" \
  -d '{"text":"","uploadedBy":"Error Test"}'

# Check error log
tail -1 ~/Projects/n8n-production/logs/errors.log | jq '.'
```

---

**Error handling is production-ready! 🛡️**

All failures are logged, retried automatically, and recoverable.
Your system is now bulletproof against common errors!
