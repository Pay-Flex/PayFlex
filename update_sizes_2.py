with open('css/style.css', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Agrandir le carousel pour masquer le bas de la page
content = content.replace('height: 75vh;', 'height: 88vh;')
content = content.replace('min-height: 450px;', 'min-height: 550px;')

# 2. Réduire l'espacement de la navbar
content = content.replace('padding: 15px 0;', 'padding: 8px 0;')

# 3. Réduire la taille de la police du logo
content = content.replace('font-size: 1.8rem !important;', 'font-size: 1.45rem !important;')

with open('css/style.css', 'w', encoding='utf-8') as f:
    f.write(content)

print("Ajustements terminés.")
