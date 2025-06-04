#!/bin/bash
# 🐚 Paguro - Test Sistema Avanzato v1.0.0
# Verifica completa operatività prima della pubblicazione

set -e

# ====================================
# CONFIGURAZIONE
# ====================================

VERSION="1.0.0"
TIMEOUT_API=180        # 3 minuti per API
TIMEOUT_OLLAMA=300     # 5 minuti per Ollama + download modello
RETRY_INTERVAL=5       # 5 secondi tra retry
MAX_RETRIES=12         # Massimo 12 retry (1 minuto)

# Colori
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
    echo ""
    echo -e "${CYAN}🧪 === $1 ===${NC}"
}

log_step() {
    echo -e "${BLUE}🔄 $1${NC}"
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

log_info() {
    echo -e "${PURPLE}ℹ️  $1${NC}"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
🐚 ===================================
   PAGURO SYSTEM TEST v1.0.0
   Villa Celi - Palinuro, Cilento
===================================
EOF
    echo -e "${NC}"
}

# ====================================
# UTILITY FUNCTIONS
# ====================================

wait_for_condition() {
    local description="$1"
    local command="$2"
    local timeout="$3"
    local interval="${4:-5}"
    
    log_step "$description"
    
    local elapsed=0
    local dots=""
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$command" >/dev/null 2>&1; then
            log_success "$description - OK"
            return 0
        fi
        
        # Progress indicator
        dots="${dots}."
        if [ ${#dots} -gt 3 ]; then
            dots="."
        fi
        
        printf "\r${BLUE}🔄 $description$dots (${elapsed}s/${timeout}s)${NC}"
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    
    echo ""
    log_error "$description - TIMEOUT dopo ${timeout}s"
    return 1
}

check_port() {
    local port="$1"
    local host="${2:-localhost}"
    
    if command -v nc >/dev/null; then
        nc -z "$host" "$port" 2>/dev/null
    elif command -v telnet >/dev/null; then
        timeout 2 telnet "$host" "$port" </dev/null >/dev/null 2>&1
    else
        # Fallback con curl
        curl -s --connect-timeout 2 "http://$host:$port" >/dev/null 2>&1
    fi
}

get_container_ip() {
    local container_name="$1"
    docker inspect "$container_name" 2>/dev/null | grep '"IPAddress"' | tail -1 | cut -d'"' -f4
}

# ====================================
# TEST FUNCTIONS
# ====================================

test_docker_environment() {
    log_header "TEST AMBIENTE DOCKER"
    
    # Verifica Docker
    if ! command -v docker >/dev/null; then
        log_error "Docker non trovato"
        return 1
    fi
    log_success "Docker disponibile"
    
    # Verifica Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose non disponibile"
        return 1
    fi
    log_success "Docker Compose disponibile"
    
    # Verifica che Docker sia in esecuzione
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon non in esecuzione"
        return 1
    fi
    log_success "Docker daemon operativo"
    
    return 0
}

test_containers_status() {
    log_header "TEST STATO CONTAINER"
    
    cd backend/ 2>/dev/null || {
        log_error "Directory backend/ non trovata"
        return 1
    }
    
    # Mostra stato container
    log_step "Verifica container in esecuzione..."
    echo ""
    docker compose ps
    echo ""
    
    # Verifica container specifici
    local containers=("paguro-api-simple" "paguro-ollama-simple")
    local failed=0
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "$container"; then
            local status=$(docker ps --filter "name=$container" --format "{{.Status}}")
            log_success "Container $container: $status"
        else
            log_error "Container $container non in esecuzione"
            ((failed++))
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log_error "$failed container non operativi"
        return 1
    fi
    
    return 0
}

test_network_connectivity() {
    log_header "TEST CONNETTIVITA' RETE"
    
    # Test porte host
    log_step "Verifica porte su host..."
    
    if check_port 5000; then
        log_success "Porta 5000 (API) raggiungibile"
    else
        log_error "Porta 5000 (API) non raggiungibile"
        return 1
    fi
    
    if check_port 11434; then
        log_success "Porta 11434 (Ollama) raggiungibile"
    else
        log_warning "Porta 11434 (Ollama) non raggiungibile dal host"
    fi
    
    # Test connettività interna container
    log_step "Verifica connettività interna container..."
    
    if docker compose exec -T paguro-api ping -c 1 ollama >/dev/null 2>&1; then
        log_success "Connettività API → Ollama OK"
    else
        log_error "Connettività API → Ollama FAIL"
        return 1
    fi
    
    return 0
}

test_ollama_service() {
    log_header "TEST SERVIZIO OLLAMA"
    
    # Wait per Ollama API
    if ! wait_for_condition "Ollama API disponibile" "curl -s http://localhost:11434/api/version" $TIMEOUT_OLLAMA; then
        log_error "Ollama API non risponde"
        log_info "Log Ollama:"
        docker logs paguro-ollama-simple --tail=20
        return 1
    fi
    
    # Verifica versione Ollama
    log_step "Verifica versione Ollama..."
    local ollama_version
    if ollama_version=$(curl -s http://localhost:11434/api/version | jq -r '.version' 2>/dev/null); then
        log_success "Ollama versione: $ollama_version"
    else
        log_warning "Impossibile determinare versione Ollama"
    fi
    
    # Verifica modelli disponibili
    log_step "Verifica modelli AI disponibili..."
    local models_response
    if models_response=$(curl -s http://localhost:11434/api/tags 2>/dev/null); then
        local model_count=$(echo "$models_response" | jq '.models | length' 2>/dev/null || echo "0")
        
        if [ "$model_count" -gt 0 ]; then
            log_success "Modelli AI disponibili: $model_count"
            
            # Verifica modello specifico llama3.2:1b
            if echo "$models_response" | jq -e '.models[] | select(.name | contains("llama3.2:1b"))' >/dev/null 2>&1; then
                log_success "Modello llama3.2:1b presente e pronto"
            else
                log_warning "Modello llama3.2:1b non trovato - verrà scaricato al primo utilizzo"
            fi
        else
            log_warning "Nessun modello AI presente - download necessario"
        fi
    else
        log_error "Impossibile verificare modelli AI"
        return 1
    fi
    
    return 0
}

test_paguro_api() {
    log_header "TEST API PAGURO"
    
    # Wait per API Flask
    if ! wait_for_condition "API Paguro disponibile" "curl -s http://localhost:5000/api/health" $TIMEOUT_API; then
        log_error "API Paguro non raggiungibile"
        log_info "Log API Paguro:"
        docker logs paguro-api-simple --tail=20
        return 1
    fi
    
    # Test health endpoint dettagliato
    log_step "Test health endpoint..."
    local health_response
    if health_response=$(curl -s http://localhost:5000/api/health 2>/dev/null); then
        
        # Parse response
        local status=$(echo "$health_response" | jq -r '.status' 2>/dev/null)
        local ollama_status=$(echo "$health_response" | jq -r '.ollama_status' 2>/dev/null)
        local database_status=$(echo "$health_response" | jq -r '.database' 2>/dev/null)
        local service_name=$(echo "$health_response" | jq -r '.service' 2>/dev/null)
        
        if [ "$status" = "ok" ]; then
            log_success "API Health: $status"
        else
            log_error "API Health: $status"
            return 1
        fi
        
        if [ "$ollama_status" = "online" ]; then
            log_success "Ollama Status: $ollama_status"
        else
            log_warning "Ollama Status: $ollama_status"
        fi
        
        if [ "$database_status" = "connected" ]; then
            log_success "Database Status: $database_status"
        else
            log_error "Database Status: $database_status"
            return 1
        fi
        
        if [ "$service_name" = "paguro_receptionist_villa_celi_fixed" ]; then
            log_success "Service Version: FIXED (con bug fixes)"
        else
            log_warning "Service Version: $service_name (potrebbe non avere tutti i fix)"
        fi
        
    else
        log_error "Health endpoint non risponde correttamente"
        return 1
    fi
    
    return 0
}

test_database() {
    log_header "TEST DATABASE"
    
    # Test database endpoint
    log_step "Test endpoint database..."
    local db_response
    if db_response=$(curl -s http://localhost:5000/api/db/appartamenti 2>/dev/null); then
        
        local record_count=$(echo "$db_response" | jq -r '.count' 2>/dev/null)
        
        if [ "$record_count" != "null" ] && [ "$record_count" -gt 0 ]; then
            log_success "Database operativo con $record_count record"
        else
            log_warning "Database vuoto o errore nel conteggio"
        fi
        
        # Verifica struttura dati
        local has_data=$(echo "$db_response" | jq -e '.data[0].appartamento' >/dev/null 2>&1 && echo "true" || echo "false")
        if [ "$has_data" = "true" ]; then
            log_success "Struttura dati database corretta"
        else
            log_warning "Struttura dati database potrebbe avere problemi"
        fi
        
    else
        log_error "Endpoint database non raggiungibile"
        return 1
    fi
    
    return 0
}

test_chatbot_functionality() {
    log_header "TEST FUNZIONALITA' CHATBOT"
    
    # Test chat semplice
    log_step "Test chat semplice (saluto)..."
    local chat_response
    if chat_response=$(curl -s -X POST http://localhost:5000/api/chatbot \
        -H "Content-Type: application/json" \
        -d '{"message": "ciao"}' 2>/dev/null); then
        
        local message_type=$(echo "$chat_response" | jq -r '.type' 2>/dev/null)
        
        if [ "$message_type" = "greeting" ]; then
            log_success "Chat semplice funzionante"
        else
            log_warning "Chat risponde ma tipo inaspettato: $message_type"
        fi
    else
        log_error "Chat semplice non funziona"
        return 1
    fi
    
    # Test disponibilità (il test critico che falliva)
    log_step "Test disponibilità (funzione critica)..."
    local availability_response
    if availability_response=$(curl -s -X POST http://localhost:5000/api/chatbot \
        -H "Content-Type: application/json" \
        -d '{"message": "disponibilità luglio 2025"}' 2>/dev/null); then
        
        local avail_type=$(echo "$availability_response" | jq -r '.type' 2>/dev/null)
        local avail_count=$(echo "$availability_response" | jq -r '.availability_count' 2>/dev/null)
        
        if [ "$avail_type" = "availability_list" ] && [ "$avail_count" != "null" ]; then
            log_success "Test disponibilità OK - $avail_count risultati trovati"
        else
            log_error "Test disponibilità FAIL - tipo: $avail_type, count: $avail_count"
            log_info "Risposta completa:"
            echo "$availability_response" | jq . 2>/dev/null || echo "$availability_response"
            return 1
        fi
    else
        log_error "Test disponibilità non risponde"
        return 1
    fi
    
    return 0
}

test_ai_integration() {
    log_header "TEST INTEGRAZIONE AI"
    
    # Test solo se Ollama ha modelli
    local models_response
    if ! models_response=$(curl -s http://localhost:11434/api/tags 2>/dev/null); then
        log_warning "Skip test AI - Ollama non raggiungibile"
        return 0
    fi
    
    local model_count=$(echo "$models_response" | jq '.models | length' 2>/dev/null || echo "0")
    
    if [ "$model_count" -eq 0 ]; then
        log_warning "Skip test AI - Nessun modello disponibile"
        log_info "Il modello verrà scaricato automaticamente al primo utilizzo"
        return 0
    fi
    
    # Test AI con domanda generica
    log_step "Test AI con domanda generica..."
    local ai_response
    if ai_response=$(curl -s -X POST http://localhost:5000/api/chatbot \
        -H "Content-Type: application/json" \
        -d '{"message": "raccontami di Palinuro"}' 2>/dev/null); then
        
        local ai_message=$(echo "$ai_response" | jq -r '.message' 2>/dev/null)
        
        if [ ${#ai_message} -gt 20 ] && [ "$ai_message" != "null" ]; then
            log_success "AI risponde correttamente (${#ai_message} caratteri)"
        else
            log_warning "AI risposta breve o vuota"
        fi
    else
        log_warning "Test AI fallito - potrebbe essere normale se il modello sta scaricando"
    fi
    
    return 0
}

show_system_summary() {
    log_header "RIEPILOGO SISTEMA"
    
    echo -e "${BLUE}📊 Stato Container:${NC}"
    docker compose ps
    
    echo ""
    echo -e "${BLUE}🌐 Endpoint Verificati:${NC}"
    echo "   • http://localhost:5000/api/health"
    echo "   • http://localhost:5000/api/chatbot"
    echo "   • http://localhost:5000/api/db/appartamenti"
    echo "   • http://localhost:11434/api/version"
    
    echo ""
    echo -e "${BLUE}💾 Utilizzo Risorse:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" paguro-api-simple paguro-ollama-simple 2>/dev/null || echo "   Info non disponibili"
    
    echo ""
    echo -e "${BLUE}📋 Log Recenti (ultime 5 righe):${NC}"
    echo -e "${YELLOW}API Paguro:${NC}"
    docker logs paguro-api-simple --tail=5 2>/dev/null | sed 's/^/   /'
    echo -e "${YELLOW}Ollama:${NC}"
    docker logs paguro-ollama-simple --tail=5 2>/dev/null | sed 's/^/   /'
}

# ====================================
# MAIN EXECUTION
# ====================================

main() {
    local start_time=$(date +%s)
    local tests_passed=0
    local tests_failed=0
    
    show_banner
    
    log_info "Avvio test completo sistema Paguro v$VERSION"
    log_info "Timeout: API=${TIMEOUT_API}s, Ollama=${TIMEOUT_OLLAMA}s"
    echo ""
    
    # Array di test da eseguire
    local tests=(
        "test_docker_environment"
        "test_containers_status" 
        "test_network_connectivity"
        "test_ollama_service"
        "test_paguro_api"
        "test_database"
        "test_chatbot_functionality"
        "test_ai_integration"
    )
    
    # Esegui tutti i test
    for test_function in "${tests[@]}"; do
        if $test_function; then
            ((tests_passed++))
        else
            ((tests_failed++))
            log_error "Test $test_function FALLITO"
        fi
        sleep 1
    done
    
    # Riepilogo finale
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    log_header "RISULTATI FINALI"
    
    echo -e "${GREEN}✅ Test passati: $tests_passed${NC}"
    echo -e "${RED}❌ Test falliti: $tests_failed${NC}"
    echo -e "${BLUE}⏱️  Tempo totale: ${duration}s${NC}"
    
    if [ $tests_failed -eq 0 ]; then
        echo ""
        log_success "🎉 TUTTI I TEST SUPERATI!"
        log_success "🐚 Paguro è PRONTO per la pubblicazione su GitHub!"
        echo ""
        echo -e "${CYAN}🚀 Prossimi passi:${NC}"
        echo "   1. Esegui: ./scripts/prepare-git.sh"
        echo "   2. Push su GitHub"
        echo "   3. Crea release v1.0.0"
        echo ""
        
        show_system_summary
        return 0
    else
        echo ""
        log_error "🚨 ALCUNI TEST SONO FALLITI"
        log_error "Risolvi i problemi prima della pubblicazione"
        echo ""
        echo -e "${YELLOW}🔧 Comandi debug utili:${NC}"
        echo "   • docker compose logs -f"
        echo "   • docker compose ps"
        echo "   • docker compose restart"
        echo ""
        
        show_system_summary
        return 1
    fi
}

# Esegui solo se script chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
