#!/bin/sh
# First-boot seeding for the n8n container (used as the container entrypoint).
# Imports the Postgres + Groq credentials and both workflows once, then starts n8n.
set -e

MARKER=/home/node/.n8n/.rag_seeded

if [ ! -f "$MARKER" ]; then
  if [ -z "$GROQ_API_KEY" ]; then
    echo "[bootstrap] WARNING: GROQ_API_KEY is empty - set it in .env, then re-seed (see README)."
  fi
  echo "[bootstrap] First boot: seeding credential and workflows..."

  cat > /tmp/credentials.json <<EOF
[
  {
    "id": "pgvaultcred0001",
    "name": "Local pgvector",
    "type": "postgres",
    "data": {
      "host": "${POSTGRES_HOST}",
      "port": 5432,
      "database": "${POSTGRES_DB}",
      "user": "${POSTGRES_USER}",
      "password": "${POSTGRES_PASSWORD}",
      "maxConnections": 10,
      "allowUnauthorizedCerts": false,
      "ssl": "disable"
    }
  },
  {
    "id": "groqheaderauth01",
    "name": "Groq API",
    "type": "httpHeaderAuth",
    "data": {
      "name": "Authorization",
      "value": "Bearer ${GROQ_API_KEY}"
    }
  }
]
EOF

  n8n import:credentials --input=/tmp/credentials.json
  n8n import:workflow --separate --input=/seed/workflows
  rm -f /tmp/credentials.json
  touch "$MARKER"
  echo "[bootstrap] Seeding done."
fi

exec n8n start
