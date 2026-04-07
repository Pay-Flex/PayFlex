/* --- PREMIUM FEATURES JS --- */

(function() {
    'use strict';

    // --- 1. SETTINGS & ASSETS ---
    const config = {
        whatsappNumber: "+22890000000",
        aiName: "PayFlex Assistant",
        aiAvatar: "img/pflex.jpeg",
        primaryColor: "#0360ec"
    };

    // --- 2. AUDIO ENGINE (Web Audio API) ---
    // Generate soft clicks and success tones without external files
    const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    
    function playClickSound() {
        if (audioCtx.state === 'suspended') audioCtx.resume();
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(800, audioCtx.currentTime);
        osc.frequency.exponentialRampToValueAtTime(100, audioCtx.currentTime + 0.1);
        gain.gain.setValueAtTime(0.1, audioCtx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.1);
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        osc.start();
        osc.stop(audioCtx.currentTime + 0.1);
    }

    function playSuccessSound() {
        if (audioCtx.state === 'suspended') audioCtx.resume();
        const nodes = [440, 554.37, 659.25]; // Major chord
        nodes.forEach((freq, i) => {
            const osc = audioCtx.createOscillator();
            const gain = audioCtx.createGain();
            osc.frequency.setValueAtTime(freq, audioCtx.currentTime + i * 0.05);
            gain.gain.setValueAtTime(0.1, audioCtx.currentTime + i * 0.05);
            gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.3 + i * 0.05);
            osc.connect(gain);
            gain.connect(audioCtx.destination);
            osc.start(audioCtx.currentTime + i * 0.05);
            osc.stop(audioCtx.currentTime + 0.3 + i * 0.05);
        });
    }

    // --- 3. INJECT HTML ELEMENTS ---
    function injectUI() {
        // Bottom Nav (Mobile Only)
        const bottomNav = document.createElement('div');
        bottomNav.className = 'premium-bottom-nav d-lg-none';
        bottomNav.innerHTML = `
            <a href="index.html" class="${window.location.pathname.includes('index') ? 'active' : ''}">
                <i class="bi bi-house-door"></i>Accueil
            </a>
            <a href="catalogue.html" class="${window.location.pathname.includes('catalogue') ? 'active' : ''}">
                <i class="bi bi-grid"></i>Catalogue
            </a>
            <a href="service.html" class="${window.location.pathname.includes('service') ? 'active' : ''}">
                <i class="bi bi-star"></i>Services
            </a>
            <a href="https://wa.me/${config.whatsappNumber}" target="_blank">
                <i class="bi bi-whatsapp"></i>Aide
            </a>
        `;
        document.body.appendChild(bottomNav);

        // WhatsApp Floating Button
        const waButton = document.createElement('a');
        waButton.href = `https://wa.me/${config.whatsappNumber}`;
        waButton.className = 'whatsapp-float d-none d-lg-flex';
        waButton.target = '_blank';
        waButton.innerHTML = '<i class="bi bi-whatsapp"></i>';
        document.body.appendChild(waButton);

        // Chatbot Widget
        const chatbot = document.createElement('div');
        chatbot.className = 'chatbot-container';
        chatbot.innerHTML = `
            <div class="chatbot-window" id="chatWindow">
                <div class="chatbot-header">
                    <img src="${config.aiAvatar}" alt="AI">
                    <div>
                        <div class="fw-bold" style="font-size: 0.9rem;">${config.aiName}</div>
                        <div style="font-size: 0.7rem; opacity: 0.8;">En ligne</div>
                    </div>
                </div>
                <div class="chatbot-messages" id="chatMessages">
                    <div class="message ai">Bonjour ! Je suis l'assistant PayFlex. Comment puis-je vous aider aujourd'hui ? 😊</div>
                </div>
                <div class="chatbot-input">
                    <input type="text" id="chatInput" placeholder="Posez une question...">
                    <button id="sendChat"><i class="bi bi-send-fill"></i></button>
                </div>
            </div>
            <div class="chatbot-toggle" id="chatToggle">
                <i class="bi bi-chat-dots-fill" style="font-size: 1.5rem;"></i>
            </div>
        `;
        document.body.appendChild(chatbot);
    }

    // --- 4. CHATBOT LOGIC ---
    function setupChatbot() {
        const toggle = document.getElementById('chatToggle');
        const window = document.getElementById('chatWindow');
        const input = document.getElementById('chatInput');
        const sendBtn = document.getElementById('sendChat');
        const messages = document.getElementById('chatMessages');

        toggle.addEventListener('click', () => {
            playClickSound();
            window.style.display = window.style.display === 'flex' ? 'none' : 'flex';
        });

        function addMessage(text, isAi = false) {
            const msg = document.createElement('div');
            msg.className = `message ${isAi ? 'ai' : 'user'}`;
            msg.textContent = text;
            messages.appendChild(msg);
            messages.scrollTop = messages.scrollHeight;
        }

        function handleResponse(userText) {
            const text = userText.toLowerCase();
            let response = "Désolé, je ne comprends pas bien. Vous pouvez me poser des questions sur nos kits mécanique, coiffure, ou sur le crédit PayFlex.";
            
            if (text.includes('mécanique')) response = "Nos kits mécanique auto sont complets et disponibles à partir de 5000 XOF/mois. 🛠️";
            else if (text.includes('coiffure')) response = "Le kit coiffure professionnel est notre best-seller, à partir de 3000 XOF/mois. ✂️";
            else if (text.includes('payflex') || text.includes('crédit')) response = "PayFlex vous permet d'acquérir votre matériel professionnel et de payer petit à petit ! 💳";
            else if (text.includes('bonjour') || text.includes('salut')) response = "Bonjour ! Comment l'aventure PayFlex peut-elle vous aider aujourd'hui ? 🚀";
            
            setTimeout(() => addMessage(response, true), 600);
        }

        sendBtn.addEventListener('click', () => {
            const val = input.value.trim();
            if (val) {
                playClickSound();
                addMessage(val);
                input.value = '';
                handleResponse(val);
            }
        });

        input.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') sendBtn.click();
        });
    }

    // --- 5. GLOBAL INTERACTIONS & CONFETTI ---
    function setupInteractions() {
        // Add click sound to all primary and secondary buttons
        document.querySelectorAll('.btn-primary, .btn-secondary, .product-item, .nav-link').forEach(el => {
            el.addEventListener('click', playClickSound);
        });

        // Trigger confetti on "Commander" or "Inscrire" buttons
        document.querySelectorAll('.btn-primary').forEach(btn => {
            if (btn.textContent.includes('Commander') || btn.textContent.includes('Inscrire')) {
                btn.addEventListener('click', () => {
                    playSuccessSound();
                    if (window.confetti) {
                        confetti({
                            particleCount: 150,
                            spread: 70,
                            origin: { y: 0.6 },
                            colors: ['#0360ec', '#fab62d', '#ffffff']
                        });
                    }
                });
            }
        });
    }

    // --- INITIALIZE ---
    window.addEventListener('DOMContentLoaded', () => {
        injectUI();
        setupChatbot();
        setupInteractions();
    });

})();
