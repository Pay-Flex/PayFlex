import glob

html_files = glob.glob('*.html')
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    if '<script>document.write(new Date().getFullYear());</script>' not in content:
        content = content.replace('&copy; 2026 <a class="fw-semi-bold"', '&copy; <script>document.write(new Date().getFullYear());</script> <a class="fw-semi-bold"')

    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print('Année automatique ajoutée avec succès.')
