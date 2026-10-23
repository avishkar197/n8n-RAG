-- ============================================================================
-- init.sql  —  runs once, on first start of the pgvector container
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ----------------------------------------------------------------------------
-- Vector store: only approved "Client Coaching" sessions ever land here.
--   stream_type = 'framework'     -> dense conceptual takeaway of the framework
--   stream_type = 'voice_sample'  -> verbatim coach dialogue (400-700 chars)
-- Embedding model: bge-m3 (1024 dims). Switch to vector(1536) if you use
-- OpenAI text-embedding-3-small instead.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS knowledge_vault (
    id          BIGSERIAL    PRIMARY KEY,
    session_id  TEXT         NOT NULL,
    stream_type TEXT         NOT NULL CHECK (stream_type IN ('framework', 'voice_sample')),
    content     TEXT         NOT NULL,
    metadata    JSONB        NOT NULL DEFAULT '{}'::jsonb,
    embedding   vector(1024) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Idempotent re-ingestion: the same chunk of the same session is upserted, not duplicated.
CREATE UNIQUE INDEX IF NOT EXISTS knowledge_vault_chunk_uniq
    ON knowledge_vault (session_id, stream_type, md5(content));

CREATE INDEX IF NOT EXISTS knowledge_vault_stream_idx
    ON knowledge_vault (stream_type);

-- HNSW approximate-nearest-neighbour index, cosine distance (matches the <=> operator).
CREATE INDEX IF NOT EXISTS knowledge_vault_embedding_hnsw
    ON knowledge_vault
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- ----------------------------------------------------------------------------
-- Flat relational archive for sessions rejected by the semantic firewall.
-- No embeddings are ever generated for these rows.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rejected_sessions (
    session_id       TEXT        PRIMARY KEY,
    title            TEXT,
    meeting_type     TEXT        NOT NULL,
    confidence_score NUMERIC(4,3) NOT NULL,
    summary          TEXT,
    reject_reason    TEXT        NOT NULL,
    session_date     TIMESTAMPTZ,
    participants     JSONB       NOT NULL DEFAULT '[]'::jsonb,
    archived_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
