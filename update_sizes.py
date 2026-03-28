with open('css/style.css', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Reduce carousel height
content = content.replace('height: 95vh;', 'height: 75vh;')
content = content.replace('min-height: 600px;', 'min-height: 450px;')

# 2. Reduce navbar link vertical padding to shrink the navbar
content = content.replace('padding: 25px 0;', 'padding: 15px 0;')

# 3. Add explicit small tweaks just in case
css = """
/* Navbar and Global size tweak */
.navbar-brand h1 {
    font-size: 1.8rem !important;
}
"""
with open('css/style.css', 'w', encoding='utf-8') as f:
    f.write(content + css)

print("Tailles réduites avec succès.")
