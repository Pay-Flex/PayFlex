with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

old_str = 'class="about-experience bg-warning rounded-4 shadow-lg p-4 text-center w-100 d-flex flex-column justify-content-center align-items-center" style="aspect-ratio: 4/5;"'
new_str = 'class="bg-warning rounded-4 shadow-lg p-4 text-center w-100 d-flex flex-column justify-content-center align-items-center" style="aspect-ratio: 4/5;"'

# We remove the "about-experience" class entirely from this specific div to prevent the old static absolute positioning from style.css
content = content.replace(old_str, new_str)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed +57 position overlay bug.")
