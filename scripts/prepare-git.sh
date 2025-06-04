#!/bin/bash
# 🐚 Paguro - Preparazione per GitHub
# Script per preparare il repository per la pubblicazione

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

VERSION="1.0.0"
REPO_URL="https://github.com/raspitin/chatbot-appartamenti.git"

echo -e "${CYAN}🐚 === PREPARAZIONE REPOSITORY GITHUB ===${NC}"
echo -e "${BLUE}📦 Versione: $VERSION${NC}"
echo -e "${YELLOW}🌐 Repository: $REPO_URL${NC}"
echo ""

# ====================================
# VERIFICA STRUTTURA PROGETTO
# ====================================

echo -e "${BLUE}📁 1. Verifica struttura progetto...${NC}"

# Verifica che siamo nella directory corretta
if [[ ! -f "README.md" || ! -d "backend" || ! -d "wordpress" ]]; then
    echo -e "${RED}❌ Esegui dalla directory root del progetto${NC}"
    echo "   Dovrebbero essere presenti: README.md, backend/, wordpress/"
    exit 1
fi

echo -e "${GREEN}✅ Struttura progetto OK${NC}"

# ====================================
# CREAZIONE FILE MANCANTI
# ====================================

echo -e "${BLUE}📝 2. Creazione file necessari...${NC}"

# Crea directory scripts se non esiste
mkdir -p scripts docs examples

# Verifica file essenziali
required_files=(
    "README.md"
    ".gitignore" 
    "LICENSE"
    "CHANGELOG.md"
    "scripts/setup.sh"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠️ File mancanti: ${missing_files[*]}${NC}"
    echo "   Assicurati di aver creato tutti i file necessari"
    read -p "Continuo comunque? [y/N]: " continue_anyway
    if [[ "$continue_anyway" != "y" ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✅ Tutti i file necessari presenti${NC}"
fi

# ====================================
# PULIZIA REPOSITORY
# ====================================

echo -e "${BLUE}🧹 3. Pulizia repository...${NC}"

# Rimuovi file temporanei
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.log" -delete 2>/dev/null || true
find . -name "*~" -delete 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Pulisci directory cache/logs (mantieni struttura)
rm -rf backend/cache/* 2>/dev/null || true
rm -rf backend/logs/* 2>/dev/null || true

# Crea file .gitkeep per mantenere directory vuote
touch backend/cache/.gitkeep
touch backend/logs/.gitkeep

echo -e "${GREEN}✅ Repository pulito${NC}"

# ====================================
# VERIFICA DATABASE
# ====================================

echo -e "${BLUE}🗄️ 4. Gestione database...${NC}"

if [[ -f "backend/data/affitti2025.db" ]]; then
    echo -e "${YELLOW}⚠️ Database esistente trovato${NC}"
    echo "   Dimensione: $(ls -lh backend/data/affitti2025.db | awk '{print $5}')"
    
    # Verifica se ha dati sensibili
    read -p "Il database contiene dati reali? [y/N]: " has_real_data
    
    if [[ "$has_real_data" == "y" ]]; then
        echo -e "${RED}🔒 Escludendo database dai commit (dati sensibili)${NC}"
        echo "backend/data/*.db" >> .gitignore
        
        # Crea database di esempio
        echo -e "${BLUE}📋 Creando database di esempio...${NC}"
        cp backend/data/affitti2025.db examples/sample-database.db
        echo -e "${GREEN}✅ Database di esempio creato in examples/${NC}"
    else
        echo -e "${GREEN}✅ Database incluso nel repository${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Nessun database trovato${NC}"
    echo "   Verrà creato automaticamente durante il setup"
fi

# ====================================
# VERIFICA GIT
# ====================================

echo -e "${BLUE}🔧 5. Configurazione Git...${NC}"

# Verifica se Git è inizializzato
if [[ ! -d ".git" ]]; then
    echo -e "${YELLOW}⚠️ Repository Git non inizializzato${NC}"
    read -p "Inizializzare Git? [Y/n]: " init_git
    
    if [[ "$init_git" != "n" ]]; then
        git init
        echo -e "${GREEN}✅ Git inizializzato${NC}"
    else
        echo -e "${RED}❌ Git necessario per continuare${NC}"
        exit 1
    fi
fi

# Verifica configurazione Git
if ! git config user.name >/dev/null; then
    echo -e "${YELLOW}⚠️ Nome utente Git non configurato${NC}"
    read -p "Inserisci il tuo nome: " git_name
    git config user.name "$git_name"
fi

if ! git config user.email >/dev/null; then
    echo -e "${YELLOW}⚠️ Email Git non configurata${NC}"
    read -p "Inserisci la tua email: " git_email
    git config user.email "$git_email"
fi

echo -e "${GREEN}✅ Git configurato${NC}"

# ====================================
# STAGING E COMMIT
# ====================================

echo -e "${BLUE}📦 6. Preparazione commit...${NC}"

# Mostra stato repository
echo -e "${CYAN}Stato attuale:${NC}"
git status --short

echo ""
read -p "Aggiungere tutti i file? [Y/n]: " add_all

if [[ "$add_all" != "n" ]]; then
    # Add tutti i file
    git add .
    
    # Mostra cosa verrà committato
    echo -e "${CYAN}File da committare:${NC}"
    git status --short
    
    echo ""
    read -p "Procedere con il commit? [Y/n]: " do_commit
    
    if [[ "$do_commit" != "n" ]]; then
        # Commit iniziale
        git commit -m "🐚 Initial commit - Paguro v$VERSION

✨ Features:
- Complete AI chatbot system with Ollama LLaMA 3.2
- WordPress plugin with auto-populate booking forms  
- Docker Compose setup with health checks
- SQLite database for apartment availability
- CORS-enabled Flask API
- Session management and booking flow

🏖️ Villa Celi - Palinuro, Cilento
🚀 Ready for production deployment"

        echo -e "${GREEN}✅ Commit iniziale creato${NC}"
    fi
fi

# ====================================
# TAG VERSION
# ====================================

echo -e "${BLUE}🏷️ 7. Creazione tag versione...${NC}"

if git tag | grep -q "v$VERSION"; then
    echo -e "${YELLOW}⚠️ Tag v$VERSION già esistente${NC}"
else
    read -p "Creare tag v$VERSION? [Y/n]: " create_tag
    
    if [[ "$create_tag" != "n" ]]; then
        git tag -a "v$VERSION" -m "🐚 Paguro v$VERSION - Stable Release

🎉 First stable release of Paguro AI chatbot
📍 Villa Celi - Palinuro, Cilento

Features:
- AI-powered booking assistant
- WordPress integration  
- Docker deployment ready
- Complete documentation

Repository: $REPO_URL"

        echo -e "${GREEN}✅ Tag v$VERSION creato${NC}"
    fi
fi

# ====================================
# REMOTE E PUSH
# ====================================

echo -e "${BLUE}🌐 8. Configurazione remote...${NC}"

# Verifica remote origin
if ! git remote get-url origin >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Remote origin non configurato${NC}"
    read -p "Aggiungere remote $REPO_URL? [Y/n]: " add_remote
    
    if [[ "$add_remote" != "n" ]]; then
        git remote add origin "$REPO_URL"
        echo -e "${GREEN}✅ Remote origin aggiunto${NC}"
    fi
else
    current_remote=$(git remote get-url origin)
    echo -e "${GREEN}✅ Remote origin: $current_remote${NC}"
fi

# Push
if git remote get-url origin >/dev/null 2>&1; then
    echo ""
    read -p "Eseguire push su GitHub? [y/N]: " do_push
    
    if [[ "$do_push" == "y" ]]; then
        echo -e "${BLUE}📤 Push su GitHub...${NC}"
        
        # Push main branch
        git push -u origin main || git push -u origin master
        
        # Push tags
        git push --tags
        
        echo -e "${GREEN}✅ Push completato!${NC}"
        echo -e "${CYAN}🌐 Repository disponibile su: $REPO_URL${NC}"
    fi
fi

# ====================================
# INFORMAZIONI FINALI
# ====================================

echo ""
echo -e "${CYAN}🎉 === PREPARAZIONE COMPLETATA ===${NC}"
echo ""
echo -e "${GREEN}✅ Repository preparato per GitHub${NC}"
echo -e "${BLUE}📦 Versione: v$VERSION${NC}"
echo -e "${YELLOW}🌐 URL: $REPO_URL${NC}"
echo ""

echo -e "${PURPLE}📋 Prossimi passi:${NC}"
echo "1. Verifica il repository su GitHub"
echo "2. Configura GitHub Pages (se necessario)"
echo "3. Setup CI/CD Actions (opzionale)"
echo "4. Crea Release ufficiale"
echo "5. Condividi con la community!"
echo ""

echo -e "${BLUE}🛠️ Comandi utili per sviluppo:${NC}"
echo "# Clone per altri sviluppatori"
echo "git clone $REPO_URL"
echo ""
echo "# Setup rapido"
echo "cd chatbot-appartamenti"
echo "./scripts/setup.sh"
echo ""
echo "# Nuova versione"
echo "git tag -a v1.1.0 -m 'New version'"
echo "git push --tags"
echo ""

echo -e "${GREEN}🐚 Paguro è pronto per il mondo!${NC}"
echo -e "${YELLOW}🏖️ Villa Celi - Palinuro, Cilento${NC}"
echo ""
