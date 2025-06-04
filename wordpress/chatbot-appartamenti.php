<?php
/**
 * Plugin Name: Paguro Chatbot Appartamenti - Villa Celi FINALE
 * Description: Sistema di prenotazione appartamenti con Paguro AI per Villa Celi a Palinuro
 * Version: 2.1.0 - FINALE FUNZIONANTE
 * Author: Villa Celi - Palinuro
 */

if (!defined('ABSPATH')) {
    exit;
}

class PaguroChatbotVillaCeliFinal {
    
    public function __construct() {
        add_action('init', array($this, 'init'));
        add_action('wp_enqueue_scripts', array($this, 'enqueue_scripts'));
        add_shortcode('paguro_chatbot', array($this, 'chatbot_shortcode'));
        add_shortcode('paguro_floating', array($this, 'floating_shortcode'));
        add_action('wp_head', array($this, 'add_typing_dots_css'), 999);
    }
    
    public function init() {
        $this->create_booking_page();
    }
    
    public function add_typing_dots_css() {
        ?>
        <style id="paguro-typing-dots-fix">
        .typing-dots {
            display: inline-flex !important;
            align-items: center !important;
            gap: 4px !important;
            margin-left: 8px !important;
        }
        .typing-dots span {
            display: inline-block !important;
            width: 6px !important;
            height: 6px !important;
            border-radius: 50% !important;
            background-color: #1e6763 !important;
            animation: paguruTypingDots 1.4s infinite ease-in-out !important;
            opacity: 0.3 !important;
            margin: 0 !important;
        }
        .typing-dots span:nth-child(1) { animation-delay: 0s !important; }
        .typing-dots span:nth-child(2) { animation-delay: 0.2s !important; }
        .typing-dots span:nth-child(3) { animation-delay: 0.4s !important; }
        @keyframes paguruTypingDots {
            0%, 60%, 100% { transform: scale(0.8) !important; opacity: 0.3 !important; }
            30% { transform: scale(1.2) !important; opacity: 1 !important; }
        }
        </style>
        <?php
    }
    
    public function enqueue_scripts() {
        wp_enqueue_style(
            'paguro-chatbot-css',
            plugin_dir_url(__FILE__) . 'assets/chatbot.css',
            array(),
            '2.1.0'
        );
        
        wp_enqueue_script(
            'paguro-chatbot-js',
            plugin_dir_url(__FILE__) . 'assets/chatbot.js',
            array('jquery'),
            '2.1.0',
            true
        );
        
        if (is_page('prenotazione')) {
            wp_enqueue_script(
                'paguro-booking-populate-js',
                plugin_dir_url(__FILE__) . 'assets/booking-populate.js',
                array('jquery'),
                '2.1.0',
                true
            );
        }
        
        wp_localize_script('paguro-chatbot-js', 'chatbot_ajax', array(
            'ajax_url' => admin_url('admin-ajax.php'),
            'nonce' => wp_create_nonce('paguro_chatbot_nonce'),
            'api_base_url' => $this->get_api_url(),
            'site_name' => 'Villa Celi - Palinuro',
            'location' => 'Palinuro, Cilento',
            'version' => '2.1.0'
        ));
    }
    
    private function get_api_url() {
        $configured_url = get_option('paguro_api_url', '');
        return !empty($configured_url) ? rtrim($configured_url, '/') : 'https://api.viamerano24.it/api';
    }
    
    public function chatbot_shortcode($atts) {
        $atts = shortcode_atts(array(
            'height' => '450px',
            'width' => '100%',
            'title' => '🐚 Paguro - Receptionist Villa Celi'
        ), $atts);
        
        ob_start();
        ?>
        <div class="chatbot-container" id="appartamenti-chatbot" style="max-width: <?php echo esc_attr($atts['width']); ?>;">
            <div class="chatbot-header">
                <?php echo esc_html($atts['title']); ?>
            </div>
            
            <div class="chat-messages" id="chat-messages">
                <div class="message bot">
                    <div class="message-bubble">
                        🐚 <strong>Ciao, sono Paguro!</strong> Il receptionist virtuale di Villa Celi a Palinuro, nel cuore del Cilento.<br><br>
                        💡 <em>Prova a scrivere: "disponibilità luglio 2025" oppure "dove si trova Villa Celi"</em>
                    </div>
                </div>
            </div>
            
            <div class="typing-indicator" id="typing-indicator" style="display: none;">
                <div class="message-bubble">
                    <span>Paguro sta pensando...</span>
                    <div class="typing-dots">
                        <span></span><span></span><span></span>
                    </div>
                </div>
            </div>
            
            <div class="chat-input-container">
                <input 
                    type="text" 
                    class="chat-input" 
                    id="chat-input" 
                    placeholder="Scrivi 'disponibilità luglio 2025' o 'dove si trova'..."
                    maxlength="200"
                >
                <button class="send-button" id="send-button" type="button">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
                    </svg>
                </button>
            </div>
        </div>
        
        <div class="booking-toast" id="booking-toast">
            <strong>🐚 Paguro ti sta reindirizzando alla prenotazione...</strong>
        </div>
        <?php
        return ob_get_clean();
    }
    
    public function floating_shortcode($atts) {
        $atts = shortcode_atts(array(
            'position' => 'bottom-right',
            'trigger_text' => '🐚 Paguro',
        ), $atts);
        
        $api_url = $this->get_api_url();
        
        ob_start();
        ?>
        <div id="floating-chatbot-trigger" onclick="toggleFloatingChatbot()" style="
            position: fixed;
            <?php echo $atts['position'] === 'bottom-left' ? 'bottom: 20px; left: 20px;' : 'bottom: 20px; right: 20px;'; ?>
            background: #1e6763;
            color: white;
            padding: 12px 16px;
            border-radius: 25px;
            cursor: pointer;
            box-shadow: 0 4px 16px rgba(30, 103, 99, 0.3);
            z-index: 9999;
            font-weight: 600;
            font-size: 14px;
            transition: all 0.3s ease;
        ">
            <?php echo esc_html($atts['trigger_text']); ?>
        </div>
        
        <div id="floating-chatbot-container" style="display: none; position: fixed; <?php echo $atts['position'] === 'bottom-left' ? 'bottom: 80px; left: 20px;' : 'bottom: 80px; right: 20px;'; ?> width: 350px; height: 450px; z-index: 9998; box-shadow: 0 8px 30px rgba(30, 103, 99, 0.25); border-radius: 12px; overflow: hidden; background: white;">
            
            <div style="background: #1e6763; color: white; padding: 15px 20px; display: flex; justify-content: space-between; align-items: center; font-weight: 600;">
                <span>🐚 Paguro - Villa Celi</span>
                <button onclick="toggleFloatingChatbot()" style="background: rgba(255,255,255,0.2); border: none; color: white; cursor: pointer; padding: 5px; width: 28px; height: 28px; border-radius: 50%;">×</button>
            </div>
            
            <div style="height: 320px; overflow-y: auto; padding: 15px; background: #fafafa;" id="floating-chat-messages">
                <div style="margin-bottom: 15px;">
                    <div style="background: white; color: #2c3e50; padding: 12px 16px; border-radius: 18px; display: inline-block; max-width: 85%; font-size: 14px; line-height: 1.4;">
                        🐚 <strong>Ciao, sono Paguro!</strong> Come posso aiutarti con Villa Celi?<br>
                        💡 <em>Prova: "disponibilità luglio 2025"</em>
                    </div>
                </div>
            </div>
            
            <div style="background: white; padding: 15px; display: flex; gap: 10px; align-items: center;">
                <input type="text" id="floating-chat-input" placeholder="Scrivi qui..." style="flex: 1; padding: 12px 16px; border: 2px solid #d0d0d0; border-radius: 25px; outline: none;">
                <button onclick="sendFloatingMessage()" style="background: #1e6763; color: white; border: none; border-radius: 50%; width: 42px; height: 42px; cursor: pointer; display: flex; align-items: center; justify-content: center;">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M2.01 21L23 12 2.01 3 2 10l15 2-15 2z"/>
                    </svg>
                </button>
            </div>
        </div>
        
        <script>
        let floatingChatbotOpen = false;
        let floatingSessionId = localStorage.getItem('paguroSessionId') || null;
        
        function toggleFloatingChatbot() {
            const container = document.getElementById('floating-chatbot-container');
            const trigger = document.getElementById('floating-chatbot-trigger');
            
            if (!floatingChatbotOpen) {
                container.style.display = 'block';
                trigger.innerHTML = '✕ Chiudi';
                trigger.style.background = '#dc3545';
                floatingChatbotOpen = true;
            } else {
                container.style.display = 'none';
                trigger.innerHTML = '<?php echo esc_js($atts['trigger_text']); ?>';
                trigger.style.background = '#1e6763';
                floatingChatbotOpen = false;
            }
        }
        
        function sendFloatingMessage() {
            const input = document.getElementById('floating-chat-input');
            const message = input.value.trim();
            
            if (!message) return;
            
            addFloatingMessage(message, 'user');
            input.value = '';
            
            const payload = { message: message };
            if (floatingSessionId) {
                payload.session_id = floatingSessionId;
            }
            
            fetch('<?php echo esc_js($api_url); ?>/chatbot', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            })
            .then(response => response.json())
            .then(data => {
                if (data.message) {
                    addFloatingMessage(data.message, 'bot');
                }
                
                if (data.session_id && data.session_id !== floatingSessionId) {
                    floatingSessionId = data.session_id;
                    localStorage.setItem('paguroSessionId', data.session_id);
                }
                
                if (data.type === 'booking_redirect' && data.booking_data) {
                    handleFloatingBooking(data.booking_data);
                }
            })
            .catch(error => {
                addFloatingMessage("⚠️ Errore di connessione. Riprova.", 'bot');
            });
        }
        
        function addFloatingMessage(message, sender) {
            const messagesContainer = document.getElementById('floating-chat-messages');
            const messageDiv = document.createElement('div');
            messageDiv.style.marginBottom = '15px';
            messageDiv.style.textAlign = sender === 'user' ? 'right' : 'left';
            
            const formattedMessage = message
                .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
                .replace(/\n/g, '<br>');
            
            const bubble = document.createElement('div');
            bubble.style.cssText = `
                display: inline-block;
                max-width: 85%;
                padding: 12px 16px;
                border-radius: 18px;
                font-size: 14px;
                line-height: 1.4;
                ${sender === 'user' ? 
                    'background: #1e6763; color: white;' : 
                    'background: white; color: #2c3e50;'
                }
            `;
            bubble.innerHTML = formattedMessage;
            
            messageDiv.appendChild(bubble);
            messagesContainer.appendChild(messageDiv);
            messagesContainer.scrollTop = messagesContainer.scrollHeight;
        }
        
        function handleFloatingBooking(bookingData) {
            if (bookingData && bookingData.appartamento) {
                const baseUrl = '<?php echo home_url('/prenotazione/'); ?>';
                const params = new URLSearchParams(bookingData).toString();
                const bookingUrl = `${baseUrl}?${params}`;
                
                addFloatingMessage(`🐚 Ti reindirizzo alla prenotazione per <strong>${bookingData.appartamento}</strong>`, 'bot');
                
                setTimeout(() => {
                    window.location.href = bookingUrl;
                }, 2000);
            }
        }
        
        document.getElementById('floating-chat-input').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                sendFloatingMessage();
            }
        });
        </script>
        <?php
        return ob_get_clean();
    }
    
    public function create_booking_page() {
        $page = get_page_by_path('prenotazione');
        
        if (!$page) {
            $page_data = array(
                'post_title' => 'Prenotazione Appartamento - Villa Celi',
                'post_content' => '
                <div id="booking-form-container">
                    <h2>🐚 Conferma la tua prenotazione con Paguro</h2>
                    <p><strong>Villa Celi - Palinuro, Cilento</strong></p>
                    
                    <div id="booking-summary" style="background: #f8fffd; padding: 20px; margin-bottom: 20px; border-radius: 8px; border: 2px solid #1e6763;">
                        <h3>📋 Riepilogo Prenotazione</h3>
                        <div id="summary-content">
                            <p><strong>Appartamento:</strong> <span id="summary-appartamento">In caricamento...</span></p>
                            <p><strong>Check-in:</strong> <span id="summary-checkin">In caricamento...</span></p>
                            <p><strong>Check-out:</strong> <span id="summary-checkout">In caricamento...</span></p>
                        </div>
                    </div>
                    
                    <div style="background: #fff; padding: 20px; border-radius: 8px;">
                        [contact-form-7 id="1" title="Prenotazione Villa Celi"]
                    </div>
                </div>
                ',
                'post_status' => 'publish',
                'post_type' => 'page',
                'post_name' => 'prenotazione'
            );
            
            wp_insert_post($page_data);
        }
    }
}

new PaguroChatbotVillaCeliFinal();

// Menu admin
add_action('admin_menu', 'paguro_admin_menu');

function paguro_admin_menu() {
    add_options_page(
        'Paguro - Villa Celi',
        'Paguro Chatbot',
        'manage_options',
        'paguro-chatbot',
        'paguro_admin_page'
    );
}

function paguro_admin_page() {
    if (isset($_POST['submit'])) {
        update_option('paguro_api_url', sanitize_url($_POST['api_url']));
        echo '<div class="notice notice-success"><p>🐚 Impostazioni salvate!</p></div>';
    }
    
    $api_url = get_option('paguro_api_url', 'https://api.viamerano24.it/api');
    ?>
    <div class="wrap">
        <h1>🐚 Paguro - Villa Celi Palinuro v2.1.0</h1>
        
        <form method="post" action="">
            <table class="form-table">
                <tr>
                    <th scope="row">URL API Paguro</th>
                    <td>
                        <input type="url" name="api_url" value="<?php echo esc_attr($api_url); ?>" class="regular-text" />
                        <p class="description">URL del server Python Paguro</p>
                    </td>
                </tr>
            </table>
            
            <?php submit_button('Salva Configurazione'); ?>
        </form>
        
        <h2>Shortcodes</h2>
        <p><code>[paguro_chatbot]</code> - Chatbot principale</p>
        <p><code>[paguro_floating]</code> - Widget floating</p>
        
        <h2>🐚 Stato Sistema</h2>
        <div id="system-status">
            <p>🔄 Controllo...</p>
        </div>
        
        <script>
        fetch('<?php echo esc_js($api_url); ?>/health')
            .then(response => response.json())
            .then(data => {
                document.getElementById('system-status').innerHTML = 
                    '<p>✅ <strong>Paguro ONLINE</strong><br>' +
                    'Status: ' + data.status + '<br>' +
                    'Ollama: ' + data.ollama.status + '</p>';
            })
            .catch(error => {
                document.getElementById('system-status').innerHTML = 
                    '<p>❌ <strong>Paguro OFFLINE</strong><br>' +
                    'Errore: ' + error.message + '</p>';
            });
        </script>
    </div>
    <?php
}
?>