# 🎯 QUICK REFERENCE CARD

## 🚀 START HERE

### 1. Activate Your Workflow (DO THIS FIRST!)
```
1. Open: http://localhost:5678
2. Import: ~/Desktop/TYSON_DOC_ANALYZER_3000.json
3. ACTIVATE the workflow (toggle switch top-right)
```

### 2. Test the Webhook
```bash
curl -X POST http://localhost:5678/webhook/upload-document \
  -H "Content-Type: application/json" \
  -d '{"text":"INVOICE #001\nTotal: $100","uploadedBy":"Tyson"}'
```

---

## 📍 KEY LOCATIONS

| What | Where |
|------|-------|
| Project | `~/Projects/n8n-production/` |
| Workflow | `~/Desktop/TYSON_DOC_ANALYZER_3000.json` |
| Guide | `~/Desktop/COMPLETE_IMPLEMENTATION_GUIDE.md` |
| Progress | `~/Desktop/IMPLEMENTATION_PROGRESS.md` |
| Tests | `~/Projects/n8n-production/tests/` |

---

## ⚡ QUICK COMMANDS

```bash
# Health check
cd ~/Projects/n8n-production && ./monitor.sh

# Backup
cd ~/Projects/n8n-production && ./backup.sh

# Check database
/opt/homebrew/Cellar/postgresql@15/15.14/bin/psql -d document_analyzer

# Test webhook
curl -X POST http://localhost:5678/webhook/upload-document \
  -F "data=@~/Projects/n8n-production/tests/test_invoice.txt" \
  -F "uploadedBy=Tyson"
```

---

## ✅ COMPLETED (55%)

- [x] Environment setup
- [x] Webhook trigger (Phase 1)
- [x] Database schema (Phase 3)
- [x] File archiving (Phase 6)
- [x] Monitoring & backup scripts

## ⏸️ REMAINING (45%)

- [ ] Import & activate workflow
- [ ] OCR integration (Phase 2)
- [ ] Database save (Phase 4)
- [ ] Slack notifications (Phase 5)
- [ ] Error handling (Phase 7)
- [ ] Testing suite (Phase 8)
- [ ] Docker deployment (Phase 9)

---

## 🆘 TROUBLESHOOTING

**Webhook returns 404?**
→ Workflow not activated. Toggle switch in N8N.

**Database connection error?**
→ Check: `brew services list | grep postgres`

**N8N not loading?**
→ Check: `curl http://localhost:5678`

---

## 📊 SYSTEM STATUS

```
N8N:        http://localhost:5678
PostgreSQL: localhost:5432 (document_analyzer)
Redis:      localhost:6379
```

---

## 🎯 TODAY'S GOAL

1. **Import workflow to N8N**
2. **Activate it**
3. **Test webhook with curl**
4. **See it process a document!**

**Time needed:** 5-10 minutes

---

**Ready? Start with step 1 above! 🚀**
