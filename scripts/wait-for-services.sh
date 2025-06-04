#!/bin/bash
# 🐚 Paguro - Wait for Services (FIXED)
# Script per attendere che tutti i servizi siano operativi

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurazione
MAX_WAIT_API=180      # 3 minuti per API
MAX_WAIT_OLLAMA=600   # 10 minuti per Ollama + download modello
CHECK_INTERVAL=5      # 5 secondi tra check

echo -e "${CYAN}🐚 === ATTESA SERVIZI PAGURO ===${NC}"
echo ""

# ====================================
# FUNZIONI UTILITY
# ====================================

log_step() {
    echo -e "${BLUE}🔄 $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

wait_with_progress() {
    local description="$1"
    local check_command="$2"
    local max_wait="$3"
    local interval="${4:-$CHECK_INTERVAL}"
    
    local elapsed=0
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spinner_index=0
    
    while [ $elapsed -lt $max_wait ]; do
        # Test condizione
        if eval "$check_command" >/dev/null 2>&1; then
            printf "\r${GREEN}✅ $description - PRONTO                    ${NC}\n"
            return 0
        fi
        
        # Progress spinner
        local spinner_char=${spinner_chars:$spinner_index:1}
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        
        printf "\r${BLUE}$spinner_char $description - Attesa ${minutes}m${seconds}s/${max_wait}s${NC}"
        
        sleep $interval
        elapsed=$((elapsed + interval))
        spinner_index=$(( (spinner_index + 1) % ${#spinner_chars} ))
    done
    
    printf "\r${RED}❌ $description - TIMEOUT dopo ${max_wait}s           ${NC}\n"
    return 1
}

# ====================================
# WAIT FUNCTIONS
# ====================================

wait_for_containers() {
    log_step "Verifica container Docker..."
    
    cd backend/ 2>/dev/null || {
        log_error "Directory backend/ non trovata"
        return 1
    }
    
    # Verifica che i container siano in running
    local containers=("paguro-api-simple" "paguro-ollama-simple")
    
    for container in "${containers[@]}"; do
        local elapsed=0
        local max_wait=30
        
        while [ $elapsed -lt $max_wait ]; do
            if docker ps | grep -q "$container"; then
                log_success "Container $container in esecuzione"
                break
            fi
            
            if [ $elapsed -eq 0 ]; then
                log_step "Attendo container $container..."
            fi
            
            sleep 2
            elapsed=$((elapsed + 2))
            
            if [ $elapsed -ge $max_wait ]; then
                log_error "Container $container non avviato dopo ${max_wait}s"
                return 1
            fi
        done
    done
    
    return 0
}

wait_for_ollama() {
    # Wait che Ollama sia raggiungibile
    if ! wait_with_progress "Ollama API disponibile" \
        "curl -s http://localhost:11434/api/version" \
        $MAX_WAIT_OLLAMA; then
        
        log_error "Ollama non raggiungibile dopo $MAX_WAIT_OLLAMA secondi"
        log_info "Log Ollama:"
        docker logs paguro-ollama-simple --tail=10
        return 1
    fi
    
    # Verifica se sta scaricando il modello
    log_step "Verifica stato modello llama3.2:1b..."
    
    local models_response
    if models_response=$(curl -s http://localhost:11434/api/tags 2>/dev/null); then
        if echo "$models_response" | jq -e '.models[] | select(.name | contains("llama3.2:1b"))' >/dev/null 2>&1; then
            log_success "Modello llama3.2:1b presente"
        else
            log_info "Modello llama3.2:1b non trovato - download al primo utilizzo"
            log_info "Dimensione: ~1.3GB - Tempo stimato: 5-10 minuti"
        fi
    else
        log_info "Impossibile verificare modelli (normale)"
    fi
    
    return 0
}

wait_for_paguro_api() {
    # Wait che API sia raggiungibile
    if ! wait_with_progress "API Paguro disponibile" \
        "curl -s http://localhost:5000/api/health" \
        $MAX_WAIT_API; then
        
        log_error "API Paguro non raggiungibile dopo $MAX_WAIT_API secondi"
        log_info "Log API:"
        docker logs paguro-api-simple --tail=10
        return 1
    fi
    
    # Verifica health
    log_step "Verifica health API..."
    local health_response
    if health_response=$(curl -s http://localhost:5000/api/health 2>/dev/null); then
        local status=$(echo "$health_response" | jq -r '.status' 2>/dev/null)
        
        if [ "$status" = "ok" ]; then
            log_success "API Health OK"
        else
            log_error "API Health: $status"
            return 1
        fi
    else
        log_error "API Health non risponde"
        return 1
    fi
    
    return 0
}

wait_for_connectivity() {
    log_step "Verifica connettività interna..."
    
    # Test connessione API → Ollama
    local elapsed=0
    local max_wait=30
    
    while [ $elapsed -lt $max_wait ]; do
        if docker compose exec -T paguro-api ping -c 1 ollama >/dev/null 2>&1; then
            log_success "Connettività API ↔ Ollama OK"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_error "Connettività interna problematica"
    return 1
}

# ====================================
# MAIN EXECUTION
# ====================================

main() {
    local start_time=$(date +%s)
    
    log_info "Attesa che tutti i servizi Paguro siano operativi..."
    log_info "Timeout massimo: API=${MAX_WAIT_API}s, Ollama=${MAX_WAIT_OLLAMA}s"
    echo ""
    
    # Sequenza di attesa
    if ! wait_for_containers; then
        log_error "Container non pronti"
        return 1
    fi
    
    echo ""
    
    if ! wait_for_ollama; then
        log_error "Ollama non pronto"
        return 1
    fi
    
    echo ""
    
    if ! wait_for_paguro_api; then
        log_error "API Paguro non pronta"
        return 1
    fi
    
    echo ""
    
    if ! wait_for_connectivity; then
        log_error "Connettività problematica"
        return 1
    fi
    
    # Success
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_success "🎉 TUTTI I SERVIZI SONO OPERATIVI!"
    log_info "Tempo di attesa: ${duration}s"
    echo ""
    
    echo -e "${CYAN}📡 Servizi disponibili:${NC}"
    echo "   • API Health:     http://localhost:5000/api/health"
    echo "   • API Chat:       http://localhost:5000/api/chatbot"
    echo "   • Ollama:         http://localhost:11434/api/version"
    echo ""
    
    return 0
}

# Esegui solo se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
