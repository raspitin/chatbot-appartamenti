/**
 * Chatbot Appartamenti - Frontend JavaScript CORRETTO
 * Compatibile con WordPress e jQuery
 * FIX: Corretto routing API per evitare conflitti
 */

(function($) {
    'use strict';

    // Configurazione
    const ChatBot = {
        config: {
            apiBaseUrl: chatbot_ajax?.api_base_url || 'https://api.viamerano24.it/api',
            ajaxUrl: chatbot_ajax?.ajax_url || '/wp-admin/admin-ajax.php',
            nonce: chatbot_ajax?.nonce || '',
            sessionId: null,
            isTyping: false,
            maxRetries: 3,
            typingDelay: 800,
            bookingPageUrl: window.location.origin + '/prenotazione/',
            // FIX: Flag per debug
            debugMode: true
        },

        // Elementi DOM
        elements: {},

        // Inizializzazione
        init: function() {
            this.bindElements();
            this.initSession();
            ChatBot.elements.input.prop('disabled', false);
            ChatBot.elements.sendButton.prop('disabled', false);
            ChatBot.elements.input.focus();
            this.bindEvents();
            this.setupScrollbar();
            console.log('🤖 Chatbot Appartamenti inizializzato');

            // Test connessione API - CORRETTO
            this.testApiConnection();
        },

        // Bind elementi DOM
        bindElements: function() {
            this.elements = {
                container: $('#appartamenti-chatbot'),
                messages: $('#chat-messages'),
                input: $('#chat-input'),
                sendButton: $('#send-button'),
                typingIndicator: $('#typing-indicator'),
                bookingToast: $('#booking-toast')
            };

            // Verifica che gli elementi esistano
            if (this.elements.container.length === 0) {
                console.warn('⚠️ Container chatbot non trovato');
            }
        },

        // Inizializzazione sessione
        initSession: function() {
            // Tenta di recuperare la sessione da localStorage
            const storedSessionId = localStorage.getItem('chatbotSessionId');
            if (storedSessionId) {
                ChatBot.config.sessionId = storedSessionId;
                console.log('Sessione recuperata:', storedSessionId);
            } else {
                console.log('Nessuna sessione trovata, verrà creata una nuova.');
            }
            // Messaggio di benvenuto
            ChatBot.displayMessage("Ciao! Sono il tuo assistente virtuale per le prenotazioni a Villa Celi. Come posso aiutarti oggi?", 'bot');
        },

        // Binding eventi
        bindEvents: function() {
            ChatBot.elements.sendButton.on('click', ChatBot.sendMessage);
            ChatBot.elements.input.on('keypress', function(e) {
                if (e.which === 13) { // Invio
                    e.preventDefault();
                    ChatBot.sendMessage();
                }
            });
            ChatBot.elements.input.on('input', ChatBot.autoResizeInput);
        },

        // Test connessione API - CORRETTO
        testApiConnection: function() {
            const testUrl = ChatBot.config.apiBaseUrl + '/health';
            console.log('🔍 Testing API connection:', testUrl);
            
            fetch(testUrl)
                .then(response => {
                    console.log('📡 API Response status:', response.status);
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.json();
                })
                .then(data => {
                    console.log('✅ API Connessione OK:', data);
                    if (ChatBot.config.debugMode) {
                        console.log('📋 API Features:', data.features);
                        console.log('📍 Location:', data.location);
                    }
                })
                .catch(error => {
                    console.error('❌ API Connessione fallita:', error);
                    ChatBot.displayMessage("⚠️ Il servizio di chat non è al momento disponibile. Riprova più tardi.", 'bot');
                    ChatBot.elements.input.prop('disabled', true);
                    ChatBot.elements.sendButton.prop('disabled', true);
                });
        },

        // Invia messaggio - CORRETTO
        sendMessage: function() {
            const messageText = ChatBot.elements.input.val().trim();
            if (messageText === '') {
                return;
            }

            if (ChatBot.config.debugMode) {
                console.log('📤 Sending message:', messageText);
            }

            ChatBot.displayMessage(messageText, 'user');
            ChatBot.elements.input.val('');
            ChatBot.autoResizeInput();

            ChatBot.elements.input.prop('disabled', true);
            ChatBot.elements.sendButton.prop('disabled', true);
            ChatBot.elements.typingIndicator.show();

            const payload = {
                message: messageText
            };
            if (ChatBot.config.sessionId) {
                payload.session_id = ChatBot.config.sessionId;
            }

            // FIX: SEMPRE usare l'API Python, MAI WordPress
            const apiUrl = ChatBot.config.apiBaseUrl + '/chatbot';
            
            if (ChatBot.config.debugMode) {
                console.log('🎯 API URL:', apiUrl);
                console.log('📦 Payload:', payload);
            }

            fetch(apiUrl, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        // Rimuovo X-WP-Nonce per l'API Python
                    },
                    body: JSON.stringify(payload)
                })
                .then(response => {
                    if (ChatBot.config.debugMode) {
                        console.log('📡 API Response status:', response.status);
                    }
                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }
                    return response.json();
                })
                .then(data => {
                    if (ChatBot.config.debugMode) {
                        console.log("📥 Risposta API completa:", data);
                    }
                    
                    ChatBot.elements.typingIndicator.hide();
                    ChatBot.elements.input.prop('disabled', false).focus();
                    ChatBot.elements.sendButton.prop('disabled', false);

                    // Gestione messaggio
                    if (data.message) {
                        ChatBot.displayMessage(data.message, 'bot');
                    } else if (data.error) {
                        ChatBot.displayMessage("❌ Errore: " + data.error, 'bot');
                    } else {
                        console.warn('⚠️ Risposta API senza messaggio:', data);
                        ChatBot.displayMessage("⚠️ Risposta non valida dal server.", 'bot');
                    }

                    if (ChatBot.config.debugMode) {
                        console.log("🔍 Tipo risposta:", data.type);
                        console.log("📋 Booking data:", data.booking_data);
                    }
                    
                    // Gestione prenotazioni
                    if (data.type === 'booking_redirect' && data.booking_data) {
                        console.log("✅ Attivando handleBookingAction...");
                        ChatBot.handleBookingAction(data.booking_data);
                    } else if (data.type === 'availability_list') {
                        console.log("📋 Lista disponibilità mostrata");
                    } else if (data.booking_data) {
                        console.log("🔄 Fallback handleBookingAction...");
                        ChatBot.handleBookingAction(data.booking_data);
                    }

                    // Gestione sessione
                    if (data.session_id && data.session_id !== ChatBot.config.sessionId) {
                        ChatBot.config.sessionId = data.session_id;
                        localStorage.setItem('chatbotSessionId', data.session_id);
                        if (ChatBot.config.debugMode) {
                            console.log('🔄 Session ID aggiornato:', ChatBot.config.sessionId);
                        }
                    }
                    
                    ChatBot.setupScrollbar();
                })
                .catch(error => {
                    console.error('❌ Errore durante la comunicazione con l\'API:', error);
                    ChatBot.elements.typingIndicator.hide();
                    
                    // Messaggio di errore più specifico
                    let errorMessage = "⚠️ Problema di connessione. ";
                    if (error.message.includes('Failed to fetch')) {
                        errorMessage += "Verifica che il server Paguro sia attivo.";
                    } else if (error.message.includes('HTTP error')) {
                        errorMessage += "Il server ha restituito un errore.";
                    } else {
                        errorMessage += "Riprova più tardi.";
                    }
                    
                    ChatBot.displayMessage(errorMessage, 'bot');
                    ChatBot.elements.input.prop('disabled', false);
                    ChatBot.elements.sendButton.prop('disabled', false);
                    ChatBot.setupScrollbar();
                });
        },

        // Visualizza messaggio - MIGLIORATO
        displayMessage: function(message, sender) {
            // Controlla se aggiungere pulsanti (prima della conversione markdown)
            let needsButtons = false;
            let buttonNumbers = [];
            
            if (sender === 'bot' && message.includes('Per prenotare')) {
                const matches = message.match(/\*\*(\d+)\.\*\*/g);
                if (matches) {
                    needsButtons = true;
                    buttonNumbers = matches.map(match => 
                        match.replace(/\*\*/g, '').replace('.', '')
                    );
                    if (ChatBot.config.debugMode) {
                        console.log('🔢 Pulsanti da creare:', buttonNumbers);
                    }
                }
            }
            
            // Converti markdown in HTML
            let formattedMessage = message
                .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                .replace(/\*(.*?)\*/g, '<em>$1</em>')
                .replace(/\n/g, '<br>')
                .replace(/💡/g, '💡')
                .replace(/✅/g, '✅')
                .replace(/🏠/g, '🏠')
                .replace(/📅/g, '📅')
                .replace(/❌/g, '❌')
                .replace(/⚠️/g, '⚠️');

            const messageBubble = $('<div>').addClass('message-bubble').html(formattedMessage);
            const messageDiv = $('<div>').addClass('message ' + sender).append(messageBubble);
            
            // Aggiungi pulsanti se necessario
            if (needsButtons && buttonNumbers.length > 0) {
                if (ChatBot.config.debugMode) {
                    console.log('✅ Aggiungendo pulsanti...');
                }
                this.addQuickActionButtons(messageBubble, buttonNumbers);
            }
            
            ChatBot.elements.messages.append(messageDiv);
            ChatBot.setupScrollbar();
        },

        // Pulsanti azione rapida
        addQuickActionButtons: function(messageBubble, buttonNumbers) {
            const quickActions = $('<div>').addClass('quick-actions');
            
            buttonNumbers.forEach(number => {
                const button = $('<button>')
                    .addClass('quick-action-btn')
                    .text(`Prenota ${number}`)
                    .data('choice', number)
                    .on('click', function() {
                        const choice = $(this).data('choice');
                        ChatBot.elements.input.val(choice);
                        ChatBot.sendMessage();
                    });
                quickActions.append(button);
            });
            
            messageBubble.append(quickActions);
            if (ChatBot.config.debugMode) {
                console.log('🎯 Pulsanti aggiunti:', buttonNumbers);
            }
        },

        // Gestione azioni booking
        handleBookingAction: function(bookingData) {
            if (ChatBot.config.debugMode) {
                console.log("🎯 handleBookingAction chiamata con:", bookingData);
            }
            
            if (bookingData && bookingData.appartamento && bookingData.check_in && bookingData.check_out) {
                ChatBot.elements.typingIndicator.hide();

                const baseUrl = ChatBot.config.bookingPageUrl;
                const params = new URLSearchParams({
                    appartamento: bookingData.appartamento,
                    check_in: bookingData.check_in,
                    check_out: bookingData.check_out,
                    check_in_formatted: bookingData.check_in_formatted,
                    check_out_formatted: bookingData.check_out_formatted
                }).toString();

                const bookingUrl = `${baseUrl}?${params}`;
                
                if (ChatBot.config.debugMode) {
                    console.log("🔗 URL generato:", bookingUrl);
                }

                const messageHtml = `
                    ✅ Perfetto! Trovata disponibilità per <strong>${bookingData.appartamento}</strong>
                    dal <strong>${bookingData.check_in_formatted}</strong> al <strong>${bookingData.check_out_formatted}</strong>.
                    <br><br>
                    🏖️ <a href="${bookingUrl}" target="_blank" class="quick-action-btn primary-btn">Vai alla prenotazione</a>
                    <br><br>
                    Oppure continua a chattare per altre domande.
                `;
                ChatBot.displayMessage(messageHtml, 'bot');

                // Redirect automatico (opzionale)
                setTimeout(() => {
                    if (ChatBot.config.debugMode) {
                        console.log("🚀 Reindirizzamento automatico...");
                    }
                    window.location.href = bookingUrl;
                }, 4000);
                
                ChatBot.setupScrollbar();
                ChatBot.elements.input.prop('disabled', false).focus();
                ChatBot.elements.sendButton.prop('disabled', false);
            } else {
                console.error("❌ Dati booking incompleti:", bookingData);
                ChatBot.displayMessage("❌ Dati di prenotazione incompleti. Riprova con una nuova ricerca.", 'bot');
                ChatBot.elements.typingIndicator.hide();
                ChatBot.elements.input.prop('disabled', false).focus();
                ChatBot.elements.sendButton.prop('disabled', false);
            }
        },

        // Scrollbar sempre in fondo
        setupScrollbar: function() {
            ChatBot.elements.messages.scrollTop(ChatBot.elements.messages[0].scrollHeight);
        },

        // Autoresize del campo input
        autoResizeInput: function() {
            ChatBot.elements.input.css('height', 'auto');
            ChatBot.elements.input.css('height', ChatBot.elements.input[0].scrollHeight + 'px');
        }
    };

    // Funzioni globali per widget floating
    window.toggleFloatingChatbot = function() {
        const container = $('#floating-chatbot-container');
        const trigger = $('#floating-chatbot-trigger');

        if (container.is(':visible')) {
            container.hide();
            trigger.html(trigger.data('original-text') || '💬 Prenota ora');
        } else {
            container.show();
            if (!trigger.data('original-text')) {
                trigger.data('original-text', trigger.html());
            }
            trigger.html('❌ Chiudi');

            // Inizializza chatbot se non già fatto
            if (!window.chatbotInitialized) {
                ChatBot.init();
                window.chatbotInitialized = true;
            }
        }
    };

    // Inizializzazione al DOM ready
    $(document).ready(function() {
        // Inizializza solo se il container esiste
        if ($('#appartamenti-chatbot').length > 0) {
            ChatBot.init();
            window.chatbotInitialized = true;
        }

        // Debug info migliorato
        if (typeof chatbot_ajax !== 'undefined') {
            console.log('🔧 Configurazione chatbot:', {
                api_url: chatbot_ajax.api_base_url,
                ajax_url: chatbot_ajax.ajax_url,
                has_nonce: !!chatbot_ajax.nonce,
                debug_mode: ChatBot.config.debugMode
            });
        } else {
            console.warn('⚠️ chatbot_ajax non definito, usando URL di default');
        }
    });

    // Esporta per debug
    window.ChatBot = ChatBot;

})(jQuery);