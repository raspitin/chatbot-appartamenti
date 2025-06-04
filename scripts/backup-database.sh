#!/bin/bash
# 🐚 Paguro - Backup Database
# Script per backup automatico database Villa Celi

set -e

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configurazione
BACKUP_DIR="backups"
DB_FILE="backend/data/affitti2025.db"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="affitti2025_backup_${TIMESTAMP}.db"

echo -e "${BLUE}🐚 === BACKUP DATABASE VILLA CELI ===${NC}"
echo ""

# Verifica database esistente
if [[ ! -f "$DB_FILE" ]]; then
    echo -e "${RED}❌ Database non trovato: $DB_FILE${NC}"
    exit 1
fi

# Crea directory backup
mkdir -p "$BACKUP_DIR"

# Backup con verifica integrità
echo -e "${BLUE}📋 Backup database in corso...${NC}"

# Test integrità prima del backup
if sqlite3 "$DB_FILE" "PRAGMA integrity_check;" | grep -q "ok"; then
    echo -e "${GREEN}✅ Integrità database verificata${NC}"
else
    echo -e "${RED}❌ Database corrotto - backup annullato${NC}"
    exit 1
fi

# Copia database
cp "$DB_FILE" "$BACKUP_DIR/$BACKUP_NAME"

# Verifica backup
if sqlite3 "$BACKUP_DIR/$BACKUP_NAME" "PRAGMA integrity_check;" | grep -q "ok"; then
    echo -e "${GREEN}✅ Backup completato: $BACKUP_DIR/$BACKUP_NAME${NC}"
    
    # Mostra info backup
    local size=$(ls -lh "$BACKUP_DIR/$BACKUP_NAME" | awk '{print $5}')
    local records=$(sqlite3 "$BACKUP_DIR/$BACKUP_NAME" "SELECT COUNT(*) FROM appartamenti;")
    
    echo -e "${BLUE}📊 Info backup:${NC}"
    echo "   • Dimensione: $size"
    echo "   • Record: $records occupazioni"
    echo "   • Data: $(date)"
    
else
    echo -e "${RED}❌ Backup corrotto${NC}"
    rm -f "$BACKUP_DIR/$BACKUP_NAME"
    exit 1
fi

# Pulizia backup vecchi (mantieni ultimi 10)
echo -e "${BLUE}🧹 Pulizia backup vecchi...${NC}"
ls -t "$BACKUP_DIR"/affitti2025_backup_*.db 2>/dev/null | tail -n +11 | xargs -r rm
echo -e "${GREEN}✅ Pulizia completata${NC}"

# Lista backup esistenti
echo ""
echo -e "${YELLOW}📋 Backup disponibili:${NC}"
ls -la "$BACKUP_DIR"/affitti2025_backup_*.db 2>/dev/null | tail -5 || echo "   Nessun backup precedente"

echo ""
echo -e "${GREEN}🎉 Backup completato con successo!${NC}"
