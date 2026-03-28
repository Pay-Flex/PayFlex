import os
import re
import glob

# 1. Remove Carousel CSS
with open('css/style.css', 'r', encoding='utf-8') as f:
    css_content = f.read()

pattern_css = r'/\* --- PREMIUM HERO CAROUSEL --- \*/.*?font-weight: 800;\n}'
css_content = re.sub(pattern_css, '', css_content, flags=re.DOTALL)

with open('css/style.css', 'w', encoding='utf-8') as f:
    f.write(css_content)

# 2. Revert HTML Animations and Update Team role
html_files = glob.glob('*.html')

for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Revert animations (mainly in index.html)
    content = content.replace('animated fadeInUp', 'animated slideInRight')
    content = content.replace('animated zoomInDown', 'animated slideInDown')
    
    # Update HIBA Divine role
    content = content.replace('Spécialiste en Transformation Digitale</p>', 'Economiste & Spécialiste en Transformation Digitale</p>')
    
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Carousel reversed and HIBA Divine role updated.")
