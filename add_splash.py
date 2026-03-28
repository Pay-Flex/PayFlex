import os

# 1. CSS Injection
css = """
/* --- SPLASH SCREEN --- */
#splash-screen {
    position: fixed;
    top: 0;
    left: 0;
    width: 100vw;
    height: 100vh;
    z-index: 9999999;
    background-color: #121212;
    display: none;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    transition: opacity 0.6s ease-out, visibility 0.6s ease-out;
}
#splash-screen.active {
    display: flex;
    opacity: 1;
    visibility: visible;
}
#splash-screen.fade-out {
    opacity: 0;
    visibility: hidden;
}
.splash-logo {
    animation: pulse-logo 2s infinite ease-in-out;
}
@keyframes pulse-logo {
    0% { transform: scale(1); }
    50% { transform: scale(1.1); }
    100% { transform: scale(1); }
}
"""
with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css)

# 2. HTML Injection in index.html
with open('index.html', 'r', encoding='utf-8') as f:
    html_content = f.read()

splash_html = """<!-- Splash Screen Start -->
    <div id="splash-screen" class="">
        <div class="text-center splash-logo">
            <h1 class="display-3 text-primary"><i class="fa fa-book-reader me-3"></i>PayFlex</h1>
            <p class="text-light mt-3 fs-5 fw-light" style="letter-spacing: 2px;">L'innovation à votre portée</p>
        </div>
    </div>
    <!-- Splash Screen End -->

    <!-- Spinner Start -->"""

html_content = html_content.replace('<!-- Spinner Start -->', splash_html)

# 3. JS Injection before </body>
js_script = """
    <script>
        document.addEventListener("DOMContentLoaded", () => {
            const splash = document.getElementById('splash-screen');
            if (splash) {
                // Check if page is reloaded
                const navigationEntries = performance.getEntriesByType("navigation");
                const isReload = (navigationEntries.length > 0 && navigationEntries[0].type === "reload") || 
                                 (performance.navigation && performance.navigation.type === 1);
                
                const isSplashShown = sessionStorage.getItem('splashShown');

                if (!isSplashShown && !isReload) {
                    splash.classList.add('active');
                    setTimeout(() => {
                        splash.classList.add('fade-out');
                        setTimeout(() => {
                            splash.style.display = 'none';
                        }, 600);
                        sessionStorage.setItem('splashShown', 'true');
                    }, 2500);
                } else {
                    splash.style.display = 'none';
                }
            }
        });
    </script>
</body>
"""

html_content = html_content.replace('</body>', js_script)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(html_content)

print("Splash screen added to index.html successfully.")
