import glob
import shutil

# 1. Create feature.html from about.html
shutil.copy('about.html', 'feature.html')
with open('feature.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('<title>PayFlex - À Propos</title>', '<title>PayFlex - Nos Avantages</title>')
content = content.replace('<h1 class="display-3 text-white mb-4 animated slideInDown">À Propos de Nous</h1>', '<h1 class="display-3 text-white mb-4 animated slideInDown">Nos Avantages</h1>')
content = content.replace('<li class="breadcrumb-item active" aria-current="page">À Propos</li>', '<li class="breadcrumb-item active" aria-current="page">Avantages</li>')
with open('feature.html', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. Update Nav and Links across all files
html_files = glob.glob('*.html')
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # Update 'En savoir plus' empty links
    content = content.replace('href=""', 'href="feature.html"')
    # Update existing anchor links
    content = content.replace('href="about.html#features"', 'href="feature.html"')

    # Clear all active states in navbar explicitly
    content = content.replace('nav-item nav-link active', 'nav-item nav-link')
    content = content.replace('dropdown-item active', 'dropdown-item')
    content = content.replace('nav-link dropdown-toggle active', 'nav-link dropdown-toggle')

    # Set active state based on filename
    if file == 'index.html':
        content = content.replace('href="index.html" class="nav-item nav-link"', 'href="index.html" class="nav-item nav-link active"')
    elif file == 'about.html':
        content = content.replace('href="about.html" class="dropdown-item"', 'href="about.html" class="dropdown-item active"')
        # Highlight parent dropdown too
        content = content.replace('class="nav-link dropdown-toggle"', 'class="nav-link dropdown-toggle active"')
    elif file == 'feature.html':
        content = content.replace('href="feature.html" class="dropdown-item"', 'href="feature.html" class="dropdown-item active"')
        content = content.replace('class="nav-link dropdown-toggle"', 'class="nav-link dropdown-toggle active"')
    elif file == 'service.html':
        content = content.replace('href="service.html" class="nav-item nav-link"', 'href="service.html" class="nav-item nav-link active"')
    elif file == 'product.html':
        content = content.replace('href="product.html" class="nav-item nav-link"', 'href="product.html" class="nav-item nav-link active"')
    elif file == 'catalogue.html':
        content = content.replace('href="catalogue.html" class="nav-item nav-link"', 'href="catalogue.html" class="nav-item nav-link active"')
    elif file == 'contact.html':
        content = content.replace('href="contact.html" class="nav-item nav-link"', 'href="contact.html" class="nav-item nav-link active"')

    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Features page created and nav active states applied successfully!")
