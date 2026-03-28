import re

with open('contact.html', 'r', encoding='utf-8') as f:
    content = f.read()

contact_regex = r'<!-- Contact Start -->.*?<!-- Contact End -->'

contact_new = """<!-- Contact Start -->
    <div class="container-xxl py-5 my-5">
        <div class="container">
            <div class="text-center mx-auto wow fadeInUp" data-wow-delay="0.1s" style="max-width: 600px;">
                <p class="section-title bg-white text-center text-primary px-3 fw-bold text-uppercase">Contactez-nous</p>
                <h1 class="mb-5 display-5 fw-bold text-dark">Si vous avez des questions, n'hésitez pas à nous contacter</h1>
            </div>
            <div class="row g-5">
                <div class="col-lg-6 wow fadeInLeft" data-wow-delay="0.1s">
                    <div class="premium-card p-5 rounded-4 shadow-lg border-0 h-100">
                        <h3 class="mb-4 fw-bolder text-dark">Besoin d'informations ?</h3>
                        <p class="mb-4 text-muted line-height-lg fs-6">Le formulaire de contact est actuellement inactif. Pour nous contacter, veuillez utiliser les informations ci-dessous.</p>
                        <form>
                            <div class="row g-4">
                                <div class="col-md-6">
                                    <div class="form-floating">
                                        <input type="text" class="form-control bg-light border-0 rounded-3 shadow-sm" id="name" placeholder="Votre Nom">
                                        <label for="name">Votre Nom</label>
                                    </div>
                                </div>
                                <div class="col-md-6">
                                    <div class="form-floating">
                                        <input type="email" class="form-control bg-light border-0 rounded-3 shadow-sm" id="email" placeholder="Votre Email">
                                        <label for="email">Votre Email</label>
                                    </div>
                                </div>
                                <div class="col-12">
                                    <div class="form-floating">
                                        <input type="text" class="form-control bg-light border-0 rounded-3 shadow-sm" id="subject" placeholder="Sujet">
                                        <label for="subject">Sujet</label>
                                    </div>
                                </div>
                                <div class="col-12">
                                    <div class="form-floating">
                                        <textarea class="form-control bg-light border-0 rounded-3 shadow-sm" placeholder="Laissez un message ici" id="message" style="height: 200px"></textarea>
                                        <label for="message">Message</label>
                                    </div>
                                </div>
                                <div class="col-12 mt-4">
                                    <button class="btn btn-primary rounded-pill py-3 px-5 fw-bold shadow-lg w-100" style="transition: all 0.3s;" type="submit"><i class="fa fa-paper-plane me-2"></i>Envoyer le Message</button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
                <div class="col-lg-6 wow fadeInRight" data-wow-delay="0.4s">
                    <div class="h-100 d-flex flex-column">
                        <h3 class="mb-4 fw-bolder text-dark">Nos Coordonnées</h3>
                        
                        <div class="d-flex align-items-center bg-light rounded-4 p-4 mb-4 shadow-sm wow slideInUp" data-wow-delay="0.1s" style="border-left: 5px solid var(--primary);">
                            <div class="bg-white rounded-circle d-flex align-items-center justify-content-center shadow-lg" style="width: 60px; height: 60px; flex-shrink: 0;">
                                <i class="fa fa-map-marker-alt text-primary fs-4"></i>
                            </div>
                            <div class="ms-4">
                                <h5 class="mb-1 fw-bold text-dark">Notre Bureau</h5>
                                <span class="text-muted">123 Rue de l'avenir, Lomé, Togo</span>
                            </div>
                        </div>

                        <div class="d-flex align-items-center bg-light rounded-4 p-4 mb-4 shadow-sm wow slideInUp" data-wow-delay="0.2s" style="border-left: 5px solid var(--secondary);">
                            <div class="bg-white rounded-circle d-flex align-items-center justify-content-center shadow-lg" style="width: 60px; height: 60px; flex-shrink: 0;">
                                <i class="fa fa-phone-alt text-secondary fs-4"></i>
                            </div>
                            <div class="ms-4">
                                <h5 class="mb-1 fw-bold text-dark">Appelez-nous</h5>
                                <span class="text-muted">+228 90 00 00 00</span>
                            </div>
                        </div>

                        <div class="d-flex align-items-center bg-light rounded-4 p-4 mb-5 shadow-sm wow slideInUp" data-wow-delay="0.3s" style="border-left: 5px solid #17a2b8;">
                            <div class="bg-white rounded-circle d-flex align-items-center justify-content-center shadow-lg" style="width: 60px; height: 60px; flex-shrink: 0;">
                                <i class="fa fa-envelope text-info fs-4"></i>
                            </div>
                            <div class="ms-4">
                                <h5 class="mb-1 fw-bold text-dark">Envoyez-nous un email</h5>
                                <span class="text-muted">contact@payflex.com</span>
                            </div>
                        </div>

                        <div class="rounded-4 overflow-hidden shadow-lg mt-auto wow zoomIn" data-wow-delay="0.4s" style="flex-grow: 1; min-height: 250px;">
                            <iframe class="w-100 h-100" src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d253840.6566879796!2d1.093106328237502!3d6.205689445032123!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x1023e2b20d38583d%3A0x3642fe434f5ca536!2sLom%C3%A9%2C%20Togo!5e0!3m2!1sen!2s!4v1678886395359!5m2!1sen!2s"
                                frameborder="0" style="min-height: 250px; border:0;" allowfullscreen="" aria-hidden="false" tabindex="0"></iframe>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <!-- Contact End -->"""

content = re.sub(contact_regex, contact_new, content, flags=re.DOTALL)

with open('contact.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Page contact complètement restructurée.")
