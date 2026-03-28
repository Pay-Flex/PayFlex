import os
import re

# 1. CSS Injection
css = """
/* --- LOADING BAR --- */
.loading-bar-container {
    width: 250px;
    height: 4px;
    background: rgba(255, 255, 255, 0.1);
    border-radius: 4px;
    overflow: hidden;
    position: relative;
    margin: 0 auto;
}
.loading-bar {
    width: 0%;
    height: 100%;
    background: var(--primary);
    border-radius: 4px;
    animation: load-bar 3s cubic-bezier(0.4, 0, 0.2, 1) forwards;
}
@keyframes load-bar {
    0% { width: 0%; }
    20% { width: 20%; }
    50% { width: 70%; }
    100% { width: 100%; }
}
"""
with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css)

# 2. HTML & JS Update
with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace HTML
pattern = r'<div id="splash-screen" class="">.*?<!-- Splash Screen End -->'
new_full_splash = """<div id="splash-screen" class="">
    <div class="text-center splash-content d-flex flex-column align-items-center">
        <img src="img/logo.png" alt="PayFlex Logo" class="splash-logo mb-3" style="max-height: 120px;">
        <p class="text-light fs-5 fw-light text-uppercase mb-4" style="letter-spacing: 4px;">L'innovation à votre portée</p>
        <div class="loading-bar-container">
            <div class="loading-bar"></div>
        </div>
    </div>
</div>
<!-- Splash Screen End -->"""

content = re.sub(pattern, new_full_splash, content, flags=re.DOTALL)

# Replace Timeout
content = content.replace('}, 2500);', '}, 3000);')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Splash screen updated with logo and loading bar.")
