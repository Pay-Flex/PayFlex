import os
import glob

# 1. Update CSS for Dark Mode
dark_mode_css = """
/* --- DARK MODE --- */
body.dark-theme {
    background-color: #121212;
    color: #e0e0e0;
}
body.dark-theme h1, body.dark-theme h2, body.dark-theme h3, body.dark-theme h4, body.dark-theme h5, body.dark-theme h6 {
    color: #ffffff;
}
body.dark-theme .bg-white {
    background-color: #1e1e1e !important;
}
body.dark-theme .bg-light {
    background-color: #2c2c2c !important;
}
body.dark-theme .glass-nav {
    background: rgba(30, 30, 30, 0.85) !important;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}
body.dark-theme .navbar .navbar-nav .nav-link {
    color: #e0e0e0;
}
body.dark-theme .navbar .navbar-nav .nav-link:hover, body.dark-theme .navbar .navbar-nav .nav-link.active {
    color: var(--secondary);
}
body.dark-theme .premium-card, body.dark-theme .service-item, body.dark-theme .product-item, body.dark-theme .team-item, body.dark-theme .premium-icon-box {
    background: #1e1e1e;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5) !important;
    border: 1px solid rgba(255, 255, 255, 0.05);
}
body.dark-theme .premium-card:hover, body.dark-theme .service-item:hover, body.dark-theme .product-item:hover, body.dark-theme .team-item:hover, body.dark-theme .premium-icon-box:hover {
    box-shadow: 0 15px 40px rgba(0, 0, 0, 0.8) !important;
}
body.dark-theme .section-title.bg-white {
    background-color: #121212 !important;
    color: var(--primary);
}
body.dark-theme .text-dark {
    color: #f8f9fa !important;
}
body.dark-theme .text-body {
    color: #cccccc !important;
}
body.dark-theme .footer {
    background-color: #0d0d0d !important;
}
body.dark-theme .back-to-top {
    box-shadow: 0 0 15px rgba(255, 255, 255, 0.1);
}
body.dark-theme .form-control {
    background-color: #2c2c2c;
    border-color: rgba(255, 255, 255, 0.1);
    color: #fff;
}
body.dark-theme .form-control:focus {
    background-color: #333333;
    color: #fff;
}
body.dark-theme .form-floating label {
    color: #888;
}

/* WOW Scroll Animations enhancements */
.wow {
    visibility: hidden;
}
"""

with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(dark_mode_css)

# 2. Create darkmode.js
os.makedirs('js', exist_ok=True)
darkmode_js = """
document.addEventListener("DOMContentLoaded", () => {
    const darkModeToggle = document.getElementById("darkModeToggle");
    const body = document.body;
    
    // Check local storage for preference
    const isDarkMode = localStorage.getItem("darkMode") === "enabled";
    if (isDarkMode) {
        body.classList.add("dark-theme");
        if(darkModeToggle) darkModeToggle.innerHTML = '<i class="fas fa-sun" style="font-size: 1.1rem;"></i>';
    }

    if (darkModeToggle) {
        darkModeToggle.addEventListener("click", () => {
            body.classList.toggle("dark-theme");
            if (body.classList.contains("dark-theme")) {
                localStorage.setItem("darkMode", "enabled");
                darkModeToggle.innerHTML = '<i class="fas fa-sun" style="font-size: 1.1rem;"></i>';
            } else {
                localStorage.setItem("darkMode", "disabled");
                darkModeToggle.innerHTML = '<i class="fas fa-moon" style="font-size: 1.1rem;"></i>';
            }
        });
    }
});
"""
with open('js/darkmode.js', 'w', encoding='utf-8') as f:
    f.write(darkmode_js)

# 3. Update all HTML files
html_files = glob.glob("*.html")
toggle_btn_html = '<button id="darkModeToggle" class="btn btn-sm btn-outline-secondary rounded-circle ms-3 d-flex align-items-center justify-content-center" style="width:38px; height:38px; border-width:2px; min-width: 38px;"><i class="fas fa-moon" style="font-size: 1.1rem;"></i></button>'

for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add dark mode button right after the navbar links
    if 'Contact</a>\n            </div>' in content and toggle_btn_html not in content:
         content = content.replace('Contact</a>\n            </div>', f'Contact</a>\n            </div>\n            {toggle_btn_html}')
             
    # Add darkmode.js before </body>
    if '<script src="js/darkmode.js"></script>' not in content:
        content = content.replace('</body>', '    <script src="js/darkmode.js"></script>\n</body>')
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

# 4. Specific "wooowwww" animations for index.html
with open('index.html', 'r', encoding='utf-8') as f:
    index_content = f.read()

# Features icons bounce and flip on scroll
index_content = index_content.replace('class="col-sm-6 wow fadeIn" data-wow-delay="0.1s"', 'class="col-sm-6 wow zoomIn" data-wow-delay="0.1s"')
index_content = index_content.replace('class="col-sm-6 wow fadeIn" data-wow-delay="0.3s"', 'class="col-sm-6 wow flipInY" data-wow-delay="0.3s"')
index_content = index_content.replace('class="col-sm-6 wow fadeIn" data-wow-delay="0.5s"', 'class="col-sm-6 wow lightSpeedIn" data-wow-delay="0.5s"')
index_content = index_content.replace('class="col-sm-6 wow fadeIn" data-wow-delay="0.7s"', 'class="col-sm-6 wow rollIn" data-wow-delay="0.6s"')

# Services Cards slide up heavily
index_content = index_content.replace('class="col-lg-4 col-md-6 pt-5 wow fadeInUp" data-wow-delay="0.1s"', 'class="col-lg-4 col-md-6 pt-5 wow bounceInUp" data-wow-delay="0.1s"')
index_content = index_content.replace('class="col-lg-4 col-md-6 pt-5 wow fadeInUp" data-wow-delay="0.3s"', 'class="col-lg-4 col-md-6 pt-5 wow bounceInUp" data-wow-delay="0.3s"')
index_content = index_content.replace('class="col-lg-4 col-md-6 pt-5 wow fadeInUp" data-wow-delay="0.5s"', 'class="col-lg-4 col-md-6 pt-5 wow bounceInUp" data-wow-delay="0.5s"')

# About section images wow effects
index_content = index_content.replace('class="col-6 position-relative wow fadeIn" data-wow-delay="0.7s"', 'class="col-6 position-relative wow bounceIn" data-wow-delay="0.7s"')
index_content = index_content.replace('class="col-6 wow fadeIn" data-wow-delay="0.1s"', 'class="col-6 wow slideInLeft" data-wow-delay="0.1s"')
index_content = index_content.replace('class="col-6 wow fadeIn" data-wow-delay="0.3s"', 'class="col-6 wow zoomInDown" data-wow-delay="0.3s"')
index_content = index_content.replace('class="col-6 wow fadeIn" data-wow-delay="0.5s"', 'class="col-6 wow slideInUp" data-wow-delay="0.5s"')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(index_content)

print("Animations super wooowww & mode sombre implémentés avec succès !")
