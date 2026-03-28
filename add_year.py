import glob

html_files = glob.glob('*.html')
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # On s'assure de ne pas ajouter l'année en double si on relance le script
    if '&copy; 2026' not in content:
        content = content.replace('&copy; <a class="fw-semi-bold"', '&copy; 2026 <a class="fw-semi-bold"')

    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print('Année ajoutée avec succès.')
