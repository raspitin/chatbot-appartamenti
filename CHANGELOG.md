# 🐚 Paguro - Changelog

Tutte le modifiche importanti al progetto saranno documentate in questo file.

Il formato è basato su [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e questo progetto aderisce al [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Multi-lingua support (EN/DE/FR)
- Integrazione calendario esterno
- Pagamenti online Stripe
- Mobile app React Native

---

## [1.0.0] - 2025-06-04

### 🎉 **Prima Release Stabile**

La prima versione completa di Paguro, receptionist virtuale AI per Villa Celi.

### ✨ Added

#### 🤖 **Core AI System**
- Sistema chatbot completo con Ollama LLaMA 3.2:1b
- Gestione conversazioni con session management
- Risposte predefinite per domande frequenti
- Fallback AI per domande generiche su Cilento/Palinuro

#### 📅 **Gestione Disponibilità**
- Calcolo automatico settimane libere (sabato-sabato)
- Database SQLite per gestione appartamenti
- Query intelligente periodi occupati vs liberi
- Formattazione date italiana (28 Giugno, 5 Luglio)

#### 🌐 **Plugin WordPress**
- Plugin completo per integrazione WordPress
- Shortcode `[paguro_chatbot]` per chat principale
- Shortcode `[paguro_floating]` per widget floating
- Auto-popolamento form Ninja Forms da chat
- Gestione booking flow completo

#### 🐳 **Docker Infrastructure**
- Docker Compose setup completo
- Container Flask API ottimizzato
- Container Ollama con download automatico modello
- Volume persistenti per dati e modelli
- Health checks per monitoraggio

#### 🔧 **API Backend**
- Flask API RESTful con CORS
- Endpoint `/api/chatbot` per chat
- Endpoint `/api/health` per monitoring
- Endpoint `/api/db/appartamenti` per debug
- Gestione errori e logging avanzato

#### 🎨 **Frontend Assets**
- CSS responsive coordinato con tema WordPress
- JavaScript per gestione chat real-time
- Sistema auto-popolamento form booking
- Typing indicators e animazioni

### 🔧 Technical Features

#### 🛡️ **Sicurezza**
- CORS configurato per domini specifici
- Input sanitization completa
- Container non-root per sicurezza
- Environment variables per configurazione

#### ⚡ **Performance**
- Cache in-memory per sessioni
- Ottimizzazione query database
- Response caching per Ollama
- Lazy loading componenti

#### 🧪 **Testing & Debug**
- Script di setup automatico
- Sistema di health check
- Debug endpoint per troubleshooting
- Log strutturati per monitoring

### 📊 **Specifiche Tecniche**

- **Python**: 3.11+
- **Flask**: 2.3.3
- **Ollama**: LLaMA 3.2:1b (1.3GB)
- **Database**: SQLite 3
- **Docker**: Compose v2
- **WordPress**: 5.8+
- **Browser**: Modern browsers (ES6+)

### 🏖️ **Villa Celi Features**

#### 🏠 **Appartamenti Supportati**
- Sistema multi-appartamento
- Configurazione flessibile nomi
- Gestione periodi occupati
- Calcolo automatico disponibilità

#### 📍 **Localizzazione Cilento**
- Risposte specifiche Palinuro/Cilento
- Informazioni turistiche locali
- Indicazioni stradali per Villa Celi
- Integrazione contesto geografico

#### 💬 **Chat Experience**
- Conversazioni naturali in italiano
- Riconoscimento intent avanzato
- Supporto richieste complesse
- Flow prenotazione guidato

### 🔧 **Bug Fixes**

#### 🐛 **Risolti in Sviluppo**
- **Datetime Comparisons**: Fix comparazioni date/datetime nel calcolo disponibilità
- **Ollama Connection**: Gestione errori connessione AI con fallback
- **Docker Entrypoint**: Risolto problema script avvio Ollama
- **CORS Issues**: Configurazione corretta per domini WordPress
- **Session Management**: Fix gestione sessioni multiple utenti
- **Line Endings**: Risolto problema entrypoint.sh su Windows/Unix

#### 🔄 **Performance Improvements**
- Ottimizzazione query appartamenti
- Cache response Ollama
- Riduzione memory footprint
- Startup time migliorato

### 📚 **Documentation**

- README completo con quick start
- Documentazione API con esempi
- Guide installazione Docker
- Setup WordPress step-by-step
- Troubleshooting guide
- Architecture overview

### 🚀 **Deployment**

- Docker Compose production-ready
- Environment configuration
- Volume management per persistenza
- Health checks monitoring
- Logging configuration

---

## [0.9.0] - 2025-05-28

### 🧪 **Beta Release**

### Added
- Prototipo sistema chatbot
- Database base appartamenti
- API Flask iniziale
- Setup Docker preliminare

### Known Issues
- Bug datetime comparisons
- Problemi connessione Ollama
- Script entrypoint instabile

---

## [0.5.0] - 2025-05-15

### 🔬 **Alpha Release**

### Added
- Proof of concept
- Base Flask application
- WordPress plugin skeleton
- Database schema design

---

## Format

### Types of Changes
- **✨ Added** for new features
- **🔧 Changed** for changes in existing functionality  
- **🗑️ Deprecated** for soon-to-be removed features
- **❌ Removed** for now removed features
- **🐛 Fixed** for any bug fixes
- **🛡️ Security** for vulnerability fixes

### Semantic Versioning
- **MAJOR** version when you make incompatible API changes
- **MINOR** version when you add functionality in a backwards compatible manner
- **PATCH** version when you make backwards compatible bug fixes

---

<p align="center">
  <strong>🐚 Paguro v1.0.0 - Stable Release</strong><br>
  <em>Villa Celi - Palinuro, Cilento</em>
</p>
