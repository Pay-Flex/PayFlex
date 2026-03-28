import glob

css = """
/* --- PREMIUM FOOTER --- */
.footer-premium {
    background-color: #1f2937 !important; /* Soft slate dark */
    color: #cbd5e1 !important;
}
.footer-premium h5 {
    color: #f8fafc !important;
}
.footer-premium .btn.btn-link {
    color: #94a3b8 !important;
}
.footer-premium .btn.btn-link:hover {
    color: var(--secondary) !important;
    letter-spacing: 1px;
}
.copyright-premium {
    background-color: #0f172a !important;
    color: #94a3b8 !important;
    border-top: 1px solid rgba(255,255,255,0.05);
}
.copyright-premium a {
    color: var(--secondary) !important;
}

/* Dark Mode overrides */
body.dark-theme .footer-premium {
    background-color: #0a0a0a !important;
    border-top: 1px solid rgba(255,255,255,0.05);
}
body.dark-theme .copyright-premium {
    background-color: #000000 !important;
}
"""
with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css)

html_files = glob.glob('*.html')
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    content = content.replace('bg-dark footer', 'footer-premium footer')
    content = content.replace('bg-secondary text-body copyright', 'copyright-premium copyright')
    content = content.replace('Designed By <a class="fw-semi-bold" href="https://htmlcodex.com">HTML Codex</a>', 'Designed By <a class="fw-semi-bold" href="https://donchaminade-alpha.vercel.app">PayFlex</a>')

    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)
print('Footer updated in all files.')
