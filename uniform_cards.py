import glob

# 1. Update CSS
css = """
/* --- UNIFORM PRODUCT CARDS --- */
.product-item {
    display: flex;
    flex-direction: column;
}
.product-item .position-relative {
    width: 100%;
    height: 240px;
    flex-shrink: 0;
    overflow: hidden;
    border-radius: 15px 15px 0 0;
}
.product-item .position-relative img {
    width: 100%;
    height: 100%;
    object-fit: cover !important;
}
.product-item .text-center {
    display: flex;
    flex-direction: column;
    flex-grow: 1;
}
.product-item .text-center p.text-muted {
    flex-grow: 1;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 3;
    -webkit-box-orient: vertical;
    margin-bottom: 1rem;
}
.product-item .text-center span.text-warning {
    margin-top: auto;
    font-weight: bold;
    font-size: 1.1rem;
}
"""

with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css)

# 2. Add h-100 safely
html_files = glob.glob('*.html')
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    # In case there are `product-item` that are not `h-100` yet.
    if 'class="product-item"' in content:
        content = content.replace('class="product-item"', 'class="product-item h-100"')
        
    with open(file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Product cards made uniform.")
