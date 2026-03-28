import re

css = """
/* --- MODAL DARK MODE FIX --- */
body.dark-theme .modal-content {
    background-color: #1e1e1e !important;
}
body.dark-theme .btn-close {
    filter: invert(1) grayscale(100%) brightness(200%);
}
"""
with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css)

with open('catalogue.html', 'r', encoding='utf-8') as f:
    c = f.read()

modal_html = """<!-- Product Modal Start -->
<div class="modal fade" id="productModal" tabindex="-1" aria-labelledby="productModalLabel" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-lg">
    <div class="modal-content premium-card border-0 shadow-lg" style="border-radius: 1rem;">
      <div class="modal-header border-bottom-0 pb-0">
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body pt-0 px-4 pb-4">
        <div class="row g-4 align-items-center">
            <div class="col-md-6 text-center">
                <img id="modalProductImg" class="img-fluid rounded-4 shadow-sm w-100" src="" alt="Product Image" style="object-fit: cover; aspect-ratio: 1/1;">
            </div>
            <div class="col-md-6">
                <span id="modalProductCategory" class="badge bg-warning mb-2 px-3 py-2 rounded-pill"></span>
                <h2 id="modalProductName" class="fw-bold mb-3 text-dark"></h2>
                <h4 id="modalProductPrice" class="text-primary mb-3"></h4>
                <p id="modalProductDesc" class="text-muted mb-4 line-height-lg"></p>
                <div class="d-flex gap-3">
                    <button class="btn btn-primary rounded-pill py-2 px-4 shadow fw-bold"><i class="fa fa-shopping-cart me-2"></i>Commander</button>
                    <button class="btn btn-outline-secondary rounded-pill py-2 px-4 shadow fw-bold" data-bs-dismiss="modal"><i class="fa fa-times me-2"></i>Fermer</button>
                </div>
            </div>
        </div>
      </div>
    </div>
  </div>
</div>
<!-- Product Modal End -->
"""

c = c.replace('</body>', modal_html + '\n</body>')

js_function = """
            function openProductModal(id) {
                const p = products.find(prod => prod.id === id);
                if(p) {
                    document.getElementById('modalProductImg').src = p.img;
                    document.getElementById('modalProductName').textContent = p.name;
                    document.getElementById('modalProductCategory').textContent = p.category;
                    document.getElementById('modalProductPrice').textContent = p.price;
                    document.getElementById('modalProductDesc').textContent = p.description;
                    var myModal = new bootstrap.Modal(document.getElementById('productModal'));
                    myModal.show();
                }
            }
"""
c = c.replace('function renderProducts() {', js_function + '\n            function renderProducts() {')

c = c.replace('<a class="d-block h5 mb-2" href="feature.html">${p.name}</a>', '<a class="d-block h5 mb-2 text-dark" href="javascript:void(0)" onclick="openProductModal(${p.id})">${p.name}</a>')

old_overlay = '<a class="btn btn-square btn-secondary rounded-circle m-1" href="#"><i class="bi bi-link"></i></a>'
new_overlay = '<a class="btn btn-square btn-secondary rounded-circle m-1" href="javascript:void(0)" onclick="openProductModal(${p.id})"><i class="bi bi-eye"></i></a>'
c = c.replace(old_overlay, new_overlay)

with open('catalogue.html', 'w', encoding='utf-8') as f:
    f.write(c)

print("Product Modal Added successfully.")
