#!/bin/bash
# 🐚 Paguro - Setup Automatico v1.0.0
# Receptionist Virtuale AI per Villa Celi
# Repository: https://github.com/raspitin/chatbot-appartamenti

set -e

# ====================================
# CONFIGURAZIONE
# ====================================

VERSION="1.0.0"
PROJECT_NAME="Paguro Villa Celi"
DOCKER_NETWORK="paguro-network"
OLLAMA_MODEL="llama3.2:1b"
REQUIRED_DOCKER_VERSION="20.10"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ====================================
# FUNZIONI UTILITY
# ====================================

log_header() {
    echo -e "${CYAN}🐚 === $1 ===${NC}"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# ====================================
# BANNER E INFORMAZIONI
# ====================================

show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ____                                
   / __ \____ _____ ___  ___________    
  / /_/ / __ `/ __ `/ / / / ___/ __ \   
 / ____/ /_/ / /_/ / /_/ / /  / /_/ /   
/_/    \__,_/\__, /\__,_/_/   \____/    
            /____/                      
EOF
    echo -e "${NC}"
    echo -e "${BLUE}🏖️  Receptionist Virtuale AI per Villa Celi${NC}"
    echo -e "${YELLOW}📍 Palinuro, Cilento - Italia${NC}"
    echo -e "${GREEN}🚀 Versione $VERSION${NC}"
    echo -e "${PURPLE}🌐 https://github.com/raspitin/chatbot-appartamenti${NC}"
    echo ""
}

show_requirements() {
    log_header "REQUISITI SISTEMA"
    echo ""
    echo -e "${BLUE}📋 Requisiti necessari:${NC}"
    echo "   • Docker Desktop (v$REQUIRED_DOCKER_VERSION+)"
    echo "   • 8GB RAM (consigliati per Ollama AI)"
    echo "   • 5GB spazio libero (per modello AI)"
    echo "   • Connessione internet (download modello)"
    echo ""
    echo -e "${YELLOW}🌐 Porte utilizzate:${NC}"
    echo "   • 5000: API Paguro"
    echo "   • 11434: Ollama AI Engine"
    echo ""
}

# ====================================
# VERIFICHE PREREQUISITI
# ====================================

check_prerequisites() {
    log_header "VERIFICA PREREQUISITI"
    echo ""
    
    local errors=0
    
    # Verifica Docker
    log_step "Controllo Docker..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker non trovato. Installa Docker Desktop da: https://docker.com/get-started"
        ((errors++))
    else
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        log_success "Docker trovato (v$docker_version)"
        
        # Verifica che Docker sia in esecuzione
        if ! docker info &> /dev/null; then
            log_error "Docker non è in esecuzione. Avvia Docker Desktop."
            ((errors++))
        else
            log_success "Docker daemon in esecuzione"
        fi
    fi
    
    # Verifica Docker Compose
    log_step "Controllo Docker Compose..."
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose non trovato. Aggiorna Docker Desktop."
        ((errors++))
    else
        local compose_version=$(docker compose version --short)
        log_success "Docker Compose trovato (v$compose_version)"
    fi
    
    # Verifica spazio disco
    log_step "Controllo spazio disco..."
    local available_space=$(df . | awk 'NR==2 {print $4}')
    local available_gb=$((available_space / 1024 / 1024))
    
    if [ $available_gb -lt 5 ]; then
        log_warning "Spazio disco limitato: ${available_gb}GB (consigliati 5GB+)"
    else
        log_success "Spazio disco sufficiente: ${available_gb}GB"
    fi
    
    # Verifica RAM
    log_step "Controllo RAM disponibile..."
    if command -v free &> /dev/null; then
        local total_ram=$(free -g | awk 'NR==2{print $2}')
        if [ $total_ram -lt 8 ]; then
            log_warning "RAM limitata: ${total_ram}GB (consigliati 8GB+ per Ollama)"
        else
            log_success "RAM sufficiente: ${total_ram}GB"
        fi
    fi
    
    # Verifica connessione internet
    log_step "Controllo connessione internet..."
    if ping -c 1 google.com &> /dev/null; then
        log_success "Connessione internet OK"
    else
        log_error "Connessione internet necessaria per download modello AI"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        log_error "Risolvi i problemi sopra prima di continuare."
        exit 1
    fi
    
    log_success "Tutti i prerequisiti soddisfatti!"
    echo ""
}

# ====================================
# SETUP DIRECTORY E FILE
# ====================================

setup_directories() {
    log_header "SETUP DIRECTORY"
    echo ""
    
    # Vai nella directory corretta
    if [[ -d "backend" ]]; then
        log_info "Rilevata directory backend, continuo setup..."
    else
        log_error "Directory 'backend' non trovata. Esegui dalla root del repository."
        exit 1
    fi
    
    cd backend/
    
    # Crea directory necessarie
    log_step "Creazione directory di lavoro..."
    mkdir -p data logs cache
    log_success "Directory create: data/, logs/, cache/"
    
    # Verifica file essenziali
    log_step "Verifica file di configurazione..."
    
    local missing_files=()
    
    if [[ ! -f "docker-compose.yml" ]]; then
        missing_files+=("docker-compose.yml")
    fi
    
    if [[ ! -f "wordpress_chatbot_api.py" ]]; then
        missing_files+=("wordpress_chatbot_api.py")
    fi
    
    if [[ ! -f "Dockerfile" ]]; then
        missing_files+=("Dockerfile")
    fi
    
    if [[ ! -f "ollama.Dockerfile" ]]; then
        missing_files+=("ollama.Dockerfile")
    fi
    
    if [[ ! -f "entrypoint.sh" ]]; then
        missing_files+=("entrypoint.sh")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "File mancanti: ${missing_files[*]}"
        log_error "Assicurati di aver clonato completamente il repository."
        exit 1
    fi
    
    log_success "Tutti i file di configurazione presenti"
    
    # Verifica permessi entrypoint
    if [[ ! -x "entrypoint.sh" ]]; then
        log_step "Impostazione permessi entrypoint.sh..."
        chmod +x entrypoint.sh
        log_success "Permessi entrypoint.sh impostati"
    fi
    
    echo ""
}

# ====================================
# GESTIONE DATABASE
# ====================================

setup_database() {
    log_header "SETUP DATABASE"
    echo ""
    
    local db_file="data/affitti2025.db"
    
    if [[ -f "$db_file" ]]; then
        log_info "Database esistente trovato: $db_file"
        
        # Verifica integrità database
        if sqlite3 "$db_file" "SELECT COUNT(*) FROM appartamenti;" &> /dev/null; then
            local count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM appartamenti;")
            log_success "Database valido con $count occupazioni registrate"
        else
            log_warning "Database corrotto, verrà ricreato"
            rm -f "$db_file"
        fi
    fi
    
    if [[ ! -f "$db_file" ]]; then
        log_step "Creazione database di esempio..."
        
        # Crea database con dati di esempio Villa Celi
        sqlite3 "$db_file" << 'EOF'
-- Database Villa Celi - Palinuro, Cilento
CREATE TABLE appartamenti (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    appartamento TEXT NOT NULL,
    check_in TEXT NOT NULL,  -- Data inizio occupazione YYYY-MM-DD
    check_out TEXT NOT NULL  -- Data fine occupazione YYYY-MM-DD
);

-- Esempio occupazioni estate 2025 (periodo OCCUPATO)
INSERT INTO appartamenti (appartamento, check_in, check_out) VALUES
-- Appartamento Corallo
('Corallo', '2025-06-07', '2025-06-14'),
('Corallo', '2025-06-21', '2025-06-28'), 
('Corallo', '2025-08-02', '2025-08-09'),
('Corallo', '2025-08-16', '2025-08-23'),

-- Appartamento Tartaruga  
('Tartaruga', '2025-06-14', '2025-06-21'),
('Tartaruga', '2025-06-28', '2025-07-05'),
('Tartaruga', '2025-07-12', '2025-07-19'),
('Tartaruga', '2025-07-26', '2025-08-02'),
('Tartaruga', '2025-08-09', '2025-08-16'),
('Tartaruga', '2025-08-23', '2025-08-30');
EOF

        log_success "Database creato con dati di esempio Villa Celi"
        
        # Verifica creazione
        local count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM appartamenti;")
        log_info "Occupazioni inserite: $count periodi"
    fi
    
    echo ""
}

# ====================================
# DOCKER SETUP
# ====================================

docker_setup() {
    log_header "DOCKER SETUP"
    echo ""
    
    # Pulizia container esistenti
    log_step "Pulizia container esistenti..."
    docker compose down --remove-orphans 2>/dev/null || true
    log_success "Container fermati"
    
    # Verifica immagini esistenti
    log_step "Verifica immagini Docker..."
    local existing_images=$(docker images | grep -E "(backend|paguro)" | wc -l)
    if [ $existing_images -gt 0 ]; then
        log_info "Trovate $existing_images immagini esistenti"
        read -p "Vuoi ricostruire le immagini? [Y/n]: " rebuild
        if [[ "$rebuild" != "n" && "$rebuild" != "N" ]]; then
            log_step "Ricostruzione immagini..."
            docker compose build --no-cache
        fi
    else
        log_step "Build immagini Docker..."
        docker compose build --no-cache
    fi
    
    log_success "Immagini Docker pronte"
    echo ""
}

# ====================================
# AVVIO SERVIZI
# ====================================

start_services() {
    log_header "AVVIO SERVIZI"
    echo ""
    
    log_step "Avvio container Docker..."
    docker compose up -d
    
    log_success "Container avviati"
    
    # Mostra stato container
    echo ""
    log_info "Stato container:"
    docker compose ps
    
    echo ""
}

# ====================================
# DOWNLOAD MODELLO AI
# ====================================

setup_ollama() {
    log_header "SETUP OLLAMA AI"
    echo ""
    
    log_info "Verificando disponibilità modello $OLLAMA_MODEL..."
    
    # Attendi che Ollama sia pronto
    log_step "Attendo che Ollama sia operativo..."
    local attempts=0
    local max_attempts=60
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s http://localhost:11434/api/version >/dev/null 2>&1; then
            log_success "Ollama operativo!"
            break
        fi
        
        ((attempts++))
        if [ $((attempts % 10)) -eq 0 ]; then
            log_info "Tentativo $attempts/$max_attempts..."
        fi
        sleep 2
    done
    
    if [ $attempts -eq $max_attempts ]; then
        log_error "Timeout: Ollama non risponde dopo $((max_attempts * 2)) secondi"
        log_info "Controlla i log: docker logs paguro-ollama-simple"
        return 1
    fi
    
    # Verifica se modello è già presente
    if docker exec paguro-ollama-simple ollama list | grep -q "$OLLAMA_MODEL"; then
        log_success "Modello $OLLAMA_MODEL già presente"
    else
        log_warning "Modello $OLLAMA_MODEL non trovato"
        log_info "Il download avverrà automaticamente al primo avvio"
        log_info "Dimensione: ~1.3GB - Tempo stimato: 5-10 minuti"
    fi
    
    echo ""
}

# ====================================
# ATTESA SERVIZI E TEST SISTEMA
# ====================================

wait_for_services() {
    log_header "ATTESA SERVIZI"
    echo ""
    
    log_info "Attendendo che tutti i servizi siano pronti..."
    log_info "Questo può richiedere fino a 10 minuti per il download del modello AI"
    
    # Usa script dedicato se disponibile
    if [[ -f "../scripts/wait-for-services.sh" ]]; then
        log_step "Usando script di attesa dedicato..."
        if ../scripts/wait-for-services.sh; then
            log_success "Tutti i servizi pronti tramite script dedicato"
            return 0
        else
            log_warning "Script di attesa fallito, provo metodo integrato"
        fi
    fi
    
    # Metodo integrato di attesa
    local max_wait_total=300  # 5 minuti totali
    local elapsed=0
    local check_interval=10
    
    while [ $elapsed -lt $max_wait_total ]; do
        log_step "Verifica servizi (tentativo $((elapsed/check_interval + 1)))..."
        
        # Test API
        if curl -s http://localhost:5000/api/health >/dev/null 2>&1; then
            local health_response=$(curl -s http://localhost:5000/api/health 2>/dev/null)
            
            if echo "$health_response" | grep -q '"status": "ok"'; then
                log_success "Servizi pronti!"
                return 0
            fi
        fi
        
        if [ $elapsed -eq 0 ]; then
            log_info "I servizi stanno ancora avviandosi..."
            log_info "Se è la prima volta, potrebbe servire tempo per scaricare il modello AI (1.3GB)"
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    log_warning "Timeout attesa servizi, ma continuo con i test..."
    return 1
}

test_system() {
    log_header "TEST SISTEMA"
    echo ""
    
    # Usa script di test dedicato se disponibile
    if [[ -f "../scripts/test-system.sh" ]]; then
        log_step "Eseguendo test completo del sistema..."
        if ../scripts/test-system.sh; then
            log_success "🎉 Tutti i test superati con script dedicato!"
            return 0
        else
            log_warning "Test script falliti, provo test base"
        fi
    fi
    
    # Test base integrati
    log_step "Eseguendo test base integrati..."
    
    # Test API Health
    log_step "Test API Health..."
    local health_response
    if health_response=$(curl -s http://localhost:5000/api/health 2>/dev/null); then
        if echo "$health_response" | grep -q '"status": "ok"'; then
            log_success "API Paguro operativa"
            
            # Verifica componenti
            if echo "$health_response" | grep -q '"ollama_status": "online"'; then
                log_success "Ollama AI connesso"
            else
                log_warning "Ollama AI offline (normale se modello in download)"
            fi
            
            if echo "$health_response" | grep -q '"database": "connected"'; then
                log_success "Database connesso"
            else
                log_warning "Database non connesso"
            fi
            
            # Verifica versione con fix
            if echo "$health_response" | grep -q '"service": "paguro_receptionist_villa_celi_fixed"'; then
                log_success "Versione FIXED con tutti i bug fix applicati"
            else
                log_warning "Versione non aggiornata - potrebbero mancare fix importanti"
            fi
        else
            log_warning "API risponde ma con errori"
        fi
    else
        log_error "API non raggiungibile"
        log_info "Verifica i log: docker compose logs paguro-api"
        return 1
    fi
    
    # Test Chat semplice
    log_step "Test chat di base..."
    local chat_response
    if chat_response=$(curl -s -X POST http://localhost:5000/api/chatbot \
        -H "Content-Type: application/json" \
        -d '{"message": "ciao"}' 2>/dev/null); then
        
        if echo "$chat_response" | grep -q '"message"'; then
            log_success "Sistema chat operativo"
        else
            log_warning "Chat risponde ma potrebbe avere problemi"
        fi
    else
        log_warning "Test chat fallito (normale se sistema ancora in avvio)"
    fi
    
    # Test critico: disponibilità (quello che falliva prima dei fix)
    log_step "Test funzione disponibilità (critica)..."
    local avail_response
    if avail_response=$(curl -s -X POST http://localhost:5000/api/chatbot \
        -H "Content-Type: application/json" \
        -d '{"message": "disponibilità luglio 2025"}' 2>/dev/null); then
        
        if echo "$avail_response" | grep -q '"availability_count"'; then
            local count=$(echo "$avail_response" | grep -o '"availability_count":[^,}]*' | cut -d: -f2)
            log_success "Test disponibilità OK ($count risultati)"
        else
            log_error "Test disponibilità FALLITO - potrebbero servire i fix del database"
            log_info "Risposta: $avail_response"
        fi
    else
        log_warning "Test disponibilità non risponde"
    fi
    
    echo ""
}

# ====================================
# INFORMAZIONI FINALI
# ====================================

show_completion_info() {
    log_header "🎉 INSTALLAZIONE COMPLETATA"
    echo ""
    
    log_success "Paguro $VERSION è ora operativo!"
    echo ""
    
    echo -e "${BLUE}📡 Endpoint disponibili:${NC}"
    echo "   • API Health:     http://localhost:5000/api/health"
    echo "   • Chat API:       http://localhost:5000/api/chatbot"
    echo "   • Database Debug: http://localhost:5000/api/db/appartamenti"
    echo "   • Ollama AI:      http://localhost:11434/api/version"
    echo ""
    
    echo -e "${YELLOW}🧪 Test rapidi:${NC}"
    echo "   # Health check"
    echo "   curl http://localhost:5000/api/health | jq"
    echo ""
    echo "   # Test disponibilità"
    echo "   curl -X POST http://localhost:5000/api/chatbot \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"message\": \"disponibilità luglio 2025\"}' | jq"
    echo ""
    
    echo -e "${PURPLE}🛠️ Comandi utili:${NC}"
    echo "   • docker compose ps              # Stato container"
    echo "   • docker compose logs -f         # Log real-time"
    echo "   • docker compose restart         # Restart servizi"
    echo "   • docker compose down            # Stop completo"
    echo ""
    
    echo -e "${GREEN}🌐 Prossimi passi:${NC}"
    echo "   1. Configura il plugin WordPress (cartella wordpress/)"
    echo "   2. Personalizza il database con i tuoi appartamenti"
    echo "   3. Integra nel tuo sito web"
    echo ""
    
    echo -e "${CYAN}📞 Supporto:${NC}"
    echo "   • Issues: https://github.com/raspitin/chatbot-appartamenti/issues"
    echo "   • Docs:   https://github.com/raspitin/chatbot-appartamenti/docs"
    echo "   • Email:  info@villaceli.it"
    echo ""
    
    echo -e "${BLUE}🏖️ Villa Celi - Palinuro, Cilento${NC}"
    echo -e "${YELLOW}🐚 Paguro: Il futuro delle prenotazioni vacanze!${NC}"
    echo ""
}

# ====================================
# MAIN EXECUTION
# ====================================

main() {
    # Ctrl+C handler
    trap 'echo -e "\n${RED}❌ Setup interrotto dall'\''utente${NC}"; exit 1' INT
    
    clear
    show_banner
    show_requirements
    
    read -p "Procedere con l'installazione? [Y/n]: " confirm
    if [[ "$confirm" == "n" || "$confirm" == "N" ]]; then
        log_info "Installazione annullata"
        exit 0
    fi
    
    echo ""
    
    # Fasi di setup
    check_prerequisites
    setup_directories
    setup_database
    docker_setup
    start_services
    wait_for_services
    setup_ollama
    test_system
    show_completion_info
    
    # Log finale
    log_success "Setup completato con successo!"
    log_info "Tempo totale: $(date)"
}

# Esegui solo se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
