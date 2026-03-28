import os
import glob

css_addition = """
/* --- PREMIUM UI/UX ADDITIONS --- */
.glass-nav {
    background: rgba(255, 255, 255, 0.85) !important;
    backdrop-filter: blur(12px);
    -webkit-backdrop-filter: blur(12px);
    box-shadow: 0 4px 30px rgba(0, 0, 0, 0.05) !important;
    border-bottom: 1px solid rgba(255, 255, 255, 0.2);
}

.premium-card {
    border-radius: 16px !important;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08) !important;
    transition: transform 0.3s ease, box-shadow 0.3s ease !important;
    border: none !important;
    background: #ffffff;
    overflow: hidden;
}

.premium-card:hover {
    transform: translateY(-8px) !important;
    box-shadow: 0 15px 40px rgba(0, 0, 0, 0.12) !important;
}

.premium-icon-box {
    border-radius: 16px !important;
    box-shadow: 0 8px 25px rgba(0,0,0,0.06) !important;
    transition: transform 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275), box-shadow 0.4s ease !important;
}
.premium-icon-box:hover {
    transform: scale(1.05) translateY(-5px) !important;
    box-shadow: 0 15px 35px rgba(0,0,0,0.12) !important;
}

/* Enhancing existing components directly */
.service-item, .product-item, .team-item, .testimonial-item {
    border-radius: 16px !important;
    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05) !important;
    transition: transform 0.3s ease, box-shadow 0.3s ease !important;
    background: #fff;
    border: 1px solid rgba(0,0,0,0.02);
}

.service-item:hover, .product-item:hover, .team-item:hover, .testimonial-item:hover {
    transform: translateY(-8px) !important;
    box-shadow: 0 20px 40px rgba(0, 0, 0, 0.12) !important;
}

/* Topbar & Header Optimization */
.topbar-premium {
    padding-top: 5px !important;
    padding-bottom: 5px !important;
    font-size: 0.9rem;
}

.page-header {
    background-position: center bottom;
}
"""

with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css_addition)

html_files = glob.glob("*.html")
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Update Navbar to use glassmorphism
    content = content.replace('bg-white navbar-light sticky-top', 'glass-nav navbar-light sticky-top')
    
    # 2. Update topbar to be more compact
    content = content.replace('py-2 px-4', 'py-1 px-4 topbar-premium')
    
    # 3. Optimize top spacing on pages
    content = content.replace('page-header py-5 mb-5', 'page-header py-4 mb-4')
    content = content.replace('container-fluid px-0 mb-5', 'container-fluid px-0 mb-4')
    
    # 4. Add hover to icon boxes
    content = content.replace('text-center bg-white py-5 px-4', 'text-center bg-white py-5 px-4 premium-icon-box')
    content = content.replace('text-center bg-primary py-5 px-4', 'text-center bg-primary py-5 px-4 premium-icon-box')
    content = content.replace('text-center bg-secondary py-5 px-4', 'text-center bg-secondary py-5 px-4 premium-icon-box')
    content = content.replace('text-center bg-warning py-5 px-4', 'text-center bg-warning py-5 px-4 premium-icon-box')
    content = content.replace('text-center  py-5 px-4', 'text-center py-5 px-4 premium-icon-box')
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("UI/UX enhancements applied successfully to HTML files and style.css!")
