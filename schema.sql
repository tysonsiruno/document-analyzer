-- DOCUMENT ANALYZER DATABASE SCHEMA
-- Created by: Tyson Siruno
-- Version: 3000.2.0

-- Main documents table
CREATE TABLE IF NOT EXISTS processed_documents (
  id SERIAL PRIMARY KEY,
  document_id VARCHAR(255) UNIQUE NOT NULL,
  file_name VARCHAR(500),
  file_type VARCHAR(100),
  file_size INTEGER,

  -- Classification
  document_type VARCHAR(50),
  classification_confidence INTEGER,
  classification_reasoning TEXT,

  -- Processing
  uploaded_by VARCHAR(255),
  uploaded_at TIMESTAMP,
  processed_at TIMESTAMP DEFAULT NOW(),
  processing_time_ms INTEGER,

  -- OCR
  ocr_used BOOLEAN DEFAULT FALSE,
  ocr_confidence INTEGER,
  ocr_engine VARCHAR(50),

  -- Results
  confidence_score INTEGER,
  confidence_level VARCHAR(50),
  approval_status VARCHAR(50),
  approval_reason TEXT,

  -- Data
  raw_text TEXT,
  extracted_data JSONB,
  validation_results JSONB,
  analysis_results JSONB,

  -- Output
  executive_summary TEXT,
  processing_notes TEXT[],

  -- Metadata
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_document_type ON processed_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_approval_status ON processed_documents(approval_status);
CREATE INDEX IF NOT EXISTS idx_uploaded_by ON processed_documents(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_uploaded_at ON processed_documents(uploaded_at);
CREATE INDEX IF NOT EXISTS idx_confidence_score ON processed_documents(confidence_score);
CREATE INDEX IF NOT EXISTS idx_processed_at ON processed_documents(processed_at);

-- Full-text search indexes
CREATE INDEX IF NOT EXISTS idx_raw_text_search ON processed_documents USING gin(to_tsvector('english', raw_text));
CREATE INDEX IF NOT EXISTS idx_summary_search ON processed_documents USING gin(to_tsvector('english', executive_summary));

-- JSONB indexes
CREATE INDEX IF NOT EXISTS idx_extracted_data ON processed_documents USING gin(extracted_data);
CREATE INDEX IF NOT EXISTS idx_metadata ON processed_documents USING gin(metadata);

-- Processing metrics table
CREATE TABLE IF NOT EXISTS processing_metrics (
  id SERIAL PRIMARY KEY,
  document_id VARCHAR(255) REFERENCES processed_documents(document_id),
  metric_name VARCHAR(100),
  metric_value NUMERIC,
  metric_unit VARCHAR(50),
  recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_metrics_doc_id ON processing_metrics(document_id);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON processing_metrics(metric_name);

-- User audit log
CREATE TABLE IF NOT EXISTS audit_log (
  id SERIAL PRIMARY KEY,
  document_id VARCHAR(255),
  action VARCHAR(100),
  user_name VARCHAR(255),
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_document ON audit_log(document_id);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_name);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action);

-- Failed documents (dead letter queue)
CREATE TABLE IF NOT EXISTS failed_documents (
  id SERIAL PRIMARY KEY,
  document_id VARCHAR(255),
  failure_reason TEXT,
  retry_count INTEGER,
  last_error TEXT,
  raw_data JSONB,
  failed_at TIMESTAMP DEFAULT NOW(),
  resolved BOOLEAN DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_failed_docs_unresolved ON failed_documents(resolved) WHERE resolved = FALSE;

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to processed_documents
DROP TRIGGER IF EXISTS update_processed_documents_updated_at ON processed_documents;
CREATE TRIGGER update_processed_documents_updated_at
  BEFORE UPDATE ON processed_documents
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- View for quick stats
CREATE OR REPLACE VIEW document_stats AS
SELECT
  document_type,
  COUNT(*) as total_count,
  AVG(confidence_score) as avg_confidence,
  AVG(processing_time_ms) as avg_processing_time_ms,
  COUNT(*) FILTER (WHERE approval_status = 'AUTO_APPROVED') as auto_approved_count,
  COUNT(*) FILTER (WHERE approval_status = 'PENDING_REVIEW') as pending_review_count,
  MAX(processed_at) as last_processed
FROM processed_documents
GROUP BY document_type;

-- View for today's processing
CREATE OR REPLACE VIEW todays_documents AS
SELECT *
FROM processed_documents
WHERE DATE(processed_at) = CURRENT_DATE
ORDER BY processed_at DESC;

-- View for recent failed documents
CREATE OR REPLACE VIEW recent_failures AS
SELECT *
FROM failed_documents
WHERE resolved = FALSE
ORDER BY failed_at DESC
LIMIT 50;

-- Grant permissions (adjust as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_user;

-- Insert initial test data
INSERT INTO audit_log (document_id, action, user_name, details)
VALUES ('SYSTEM', 'DATABASE_INITIALIZED', 'system', '{"version": "3000.2.0", "created_by": "Tyson Siruno"}'::JSONB)
ON CONFLICT DO NOTHING;

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Database schema created successfully!';
  RAISE NOTICE '📊 Tables created: processed_documents, processing_metrics, audit_log, failed_documents';
  RAISE NOTICE '🔍 Views created: document_stats, todays_documents, recent_failures';
  RAISE NOTICE '⚡ Indexes optimized for fast queries';
  RAISE NOTICE '🚀 Ready for production use!';
END $$;
