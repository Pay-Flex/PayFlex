import os
import re

css = """
.line-height-lg { line-height: 1.8 !important; }
.letter-spacing-1 { letter-spacing: 1px !important; }
.drop-shadow { filter: drop-shadow(2px 4px 6px rgba(0,0,0,0.15)); }
.rounded-4 { border-radius: 1rem !important; }
"""
with open('css/style.css', 'a', encoding='utf-8') as f: f.write(css)
with open('index.html', 'r', encoding='utf-8') as f: c = f.read()

# 1. ABOUT
about_new = """<!-- About Start -->
    <div class="container-xxl py-5 my-5">
        <div class="container">
            <div class="row g-5 align-items-center">
                <div class="col-lg-6 wow fadeInUp" data-wow-delay="0.1s">
                    <div class="row g-4">
                        <div class="col-6"><img class="img-fluid rounded-4 shadow-lg mb-4 w-100" src="img/service-1.jpg" style="object-fit: cover; aspect-ratio: 4/5;"></div>
                        <div class="col-6"><img class="img-fluid rounded-4 shadow-lg w-100" src="img/service-2.jpg" style="object-fit: cover; aspect-ratio: 4/5;"></div>
                        <div class="col-6"><img class="img-fluid rounded-4 shadow-lg w-100" src="img/service-3.jpg" style="object-fit: cover; aspect-ratio: 4/5;"></div>
                        <div class="col-6 d-flex align-items-center justify-content-center">
                            <div class="about-experience bg-warning rounded-4 shadow-lg p-4 text-center w-100 d-flex flex-column justify-content-center align-items-center" style="aspect-ratio: 4/5;">
                                <h1 class="display-3 mb-2 fw-bolder text-dark">+57</h1>
                                <span class="fs-5 fw-bold text-dark text-uppercase letter-spacing-1">spécialités</span>
                            </div>
                        </div>
                    </div>
                </div>
                <div class="col-lg-6 wow fadeIn" data-wow-delay="0.5s">
                    <p class="section-title bg-white text-start text-primary pe-3 fw-bold text-uppercase">À Propos de Nous</p>
                    <h1 class="mb-4 display-5 fw-bold text-dark">Découvrez PayFlex et notre mission</h1>
                    <p class="mb-4 fs-5 text-muted line-height-lg">PayFlex est une plateforme numérique conçue pour les jeunes apprentis et artisans, leur permettant d'acquérir les outils et kits de travail essentiels grâce à des paiements échelonnés. Notre mission est de lever les barrières financières qui empêchent les talents de démarrer leur carrière.</p>
                    <div class="row g-4 pt-4 mb-5">
                        <div class="col-sm-6 d-flex">
                            <div class="d-flex flex-column align-items-start">
                                <div class="bg-light rounded-circle d-flex justify-content-center align-items-center mb-3 shadow-sm" style="width: 60px; height: 60px;"><img class="img-fluid p-2" src="img/service.png"></div>
                                <h5 class="mb-2 fw-bold text-dark">Accessibilité et flexibilité</h5><p class="text-muted mb-0">Payez en plusieurs fois, selon vos revenus.</p>
                            </div>
                        </div>
                        <div class="col-sm-6 d-flex">
                            <div class="d-flex flex-column align-items-start">
                                <div class="bg-light rounded-circle d-flex justify-content-center align-items-center mb-3 shadow-sm" style="width: 60px; height: 60px;"><img class="img-fluid p-2" src="img/product.png"></div>
                                <h5 class="mb-2 fw-bold text-dark">Qualité et fiabilité</h5><p class="text-muted mb-0">Des outils et kits certifiés avec des garanties.</p>
                            </div>
                        </div>
                    </div>
                    <a class="btn btn-primary rounded-pill py-3 px-5 fw-bold shadow" href="feature.html">En savoir plus</a>
                </div>
            </div>
        </div>
    </div>
    <!-- About End -->"""
c = re.sub(r'<!-- About Start -->.*?<!-- About End -->', about_new, c, flags=re.DOTALL)

# 2. GRAPHIC
graphic_new = """<!-- Graphic Section Start -->
    <div class="container-xxl py-5 my-5 bg-light rounded-4 shadow-sm" style="position: relative; overflow: hidden;">
        <div class="container py-5">
            <div class="row g-5 align-items-center">
                <div class="col-lg-6 wow fadeIn" data-wow-delay="0.1s">
                    <p class="section-title bg-light text-start text-primary pe-3 fw-bold text-uppercase">Notre Vision</p>
                    <h1 class="mb-4 display-5 fw-bold text-dark">Technologie et Flexibilité au service des apprentis et de leur avenir</h1>
                    <p class="mb-4 fs-5 text-muted line-height-lg">Nous croyons que la technologie peut libérer le potentiel. Notre plateforme est conçue pour être intuitive, sécurisée et s'adapter à vos besoins, vous donnant la liberté de vous concentrer sur ce que vous faites de mieux : votre métier.</p>
                    <p class="text-muted fs-5">Le graphique ci-contre symbolise la connexion, la croissance et la flexibilité que PayFlex apporte à chaque artisan. C'est notre engagement envers votre réussite.</p>
                </div>
                <div class="col-lg-6 wow zoomIn" data-wow-delay="0.3s">
                    <div class="custom-graphic-container d-flex justify-content-center align-items-center p-5 bg-white rounded-circle shadow-lg" style="width: 100%; max-width: 450px; aspect-ratio: 1/1; margin: 0 auto;">
                        <svg class="custom-graphic" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" style="width: 80%; height: 80%;"><path d="M1024 512c0 282.77-229.23 512-512 512S0 794.77 0 512 229.23 0 512 0s512 229.23 512 512z m-512 448c247.42 0 448-200.58 448-448S759.42 64 512 64 64 264.58 64 512s200.58 448 448 448z m0-128c-176.73 0-320-143.27-320-320s143.27-320 320-320 320 143.27 320 320-143.27 320-320 320z m0-64c141.38 0 256-114.62 256-256S653.38 256 512 256 256 370.62 256 512s114.62 256 256 256z m0-128c-70.69 0-128-57.31-128-128s57.31-128 128-128 128 57.31 128 128-57.31 128-128 128z m0-64c35.35 0 64-28.65 64-64s-28.65-64-64-64-64 28.65-64 64 28.65 64 64 64z" fill="var(--primary)"/></svg>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <!-- Graphic Section End -->"""
c = re.sub(r'<!-- Graphic Section Start -->.*?<!-- Graphic Section End -->', graphic_new, c, flags=re.DOTALL)

# 3. FEATURES
features_new = """<!-- Features Start -->
    <div class="container-xxl py-5 my-5">
        <div class="container">
            <div class="row g-5 align-items-center">
                <div class="col-lg-6 wow fadeInUp" data-wow-delay="0.1s">
                    <p class="section-title bg-white text-start text-primary pe-3 fw-bold text-uppercase">Pourquoi Nous Choisir !</p>
                    <h1 class="mb-4 display-5 fw-bold text-dark">Les avantages de PayFlex pour votre avenir</h1>
                    <p class="mb-4 fs-5 text-muted line-height-lg">PayFlex vous offre bien plus qu'une simple solution de paiement. Nous vous accompagnons à chaque étape de votre parcours professionnel.</p>
                    
                    <div class="d-flex align-items-center mb-3 p-3 bg-light rounded-4 shadow-sm wow slideInLeft" data-wow-delay="0.2s">
                        <div class="bg-primary text-white rounded-circle d-flex align-items-center justify-content-center shadow" style="width: 55px; height: 55px; flex-shrink: 0;"><i class="fa fa-check fs-4"></i></div>
                        <p class="ms-4 mb-0 fs-5 fw-medium text-dark line-height-lg">Accompagnement et conseils personnalisés</p>
                    </div>
                    <div class="d-flex align-items-center mb-3 p-3 bg-light rounded-4 shadow-sm wow slideInLeft" data-wow-delay="0.4s">
                        <div class="bg-primary text-white rounded-circle d-flex align-items-center justify-content-center shadow" style="width: 55px; height: 55px; flex-shrink: 0;"><i class="fa fa-check fs-4"></i></div>
                        <p class="ms-4 mb-0 fs-5 fw-medium text-dark line-height-lg">Services complémentaires (maintenance, location, etc.)</p>
                    </div>
                    <div class="d-flex align-items-center mb-4 p-3 bg-light rounded-4 shadow-sm wow slideInLeft" data-wow-delay="0.6s">
                        <div class="bg-primary text-white rounded-circle d-flex align-items-center justify-content-center shadow" style="width: 55px; height: 55px; flex-shrink: 0;"><i class="fa fa-check fs-4"></i></div>
                        <p class="ms-4 mb-0 fs-5 fw-medium text-dark line-height-lg">Une communauté de professionnels pour échanger</p>
                    </div>
                    <a class="btn btn-primary rounded-pill py-3 px-5 mt-3 fw-bold shadow" href="feature.html">En savoir plus</a>
                </div>
                <div class="col-lg-6">
                    <div class="row g-4">
                        <div class="col-sm-6 wow zoomIn" data-wow-delay="0.1s">
                            <div class="premium-card p-5 text-center d-flex flex-column align-items-center justify-content-center h-100" style="border-top: 6px solid var(--primary) !important;">
                                <img class="img-fluid mb-4 drop-shadow" src="img/experience.png" style="height: 70px; object-fit: contain;">
                                <h1 class="display-5 fw-bolder text-primary mb-2" data-toggle="counter-up">45000</h1>
                                <span class="fs-5 fw-semibold text-muted text-uppercase letter-spacing-1">Apprentis</span>
                            </div>
                        </div>
                        <div class="col-sm-6 wow flipInY" data-wow-delay="0.3s">
                            <div class="premium-card p-5 text-center d-flex flex-column align-items-center justify-content-center h-100" style="border-top: 6px solid var(--secondary) !important;">
                                <img class="img-fluid mb-4 drop-shadow" src="img/award.png" style="height: 70px; object-fit: contain;">
                                <h1 class="display-5 fw-bolder text-secondary mb-2" data-toggle="counter-up">15</h1>
                                <span class="fs-5 fw-semibold text-muted text-uppercase letter-spacing-1">Partenaires</span>
                            </div>
                        </div>
                        <div class="col-sm-6 wow lightSpeedIn" data-wow-delay="0.5s">
                            <div class="premium-card p-5 text-center d-flex flex-column align-items-center justify-content-center h-100" style="border-top: 6px solid #17a2b8 !important;">
                                <img class="img-fluid mb-4 drop-shadow" src="img/animal.png" style="height: 70px; object-fit: contain;">
                                <h1 class="display-5 fw-bolder text-info mb-2" data-toggle="counter-up">30000</h1>
                                <span class="fs-5 fw-semibold text-muted text-uppercase letter-spacing-1">Utilisateurs</span>
                            </div>
                        </div>
                        <div class="col-sm-6 wow rollIn" data-wow-delay="0.6s">
                            <div class="premium-card p-5 text-center d-flex flex-column align-items-center justify-content-center h-100" style="border-top: 6px solid #28a745 !important;">
                                <img class="img-fluid mb-4 drop-shadow" src="img/client.png" style="height: 70px; object-fit: contain;">
                                <h1 class="display-5 fw-bolder text-success mb-2" data-toggle="counter-up">5</h1>
                                <span class="fs-5 fw-semibold text-muted text-uppercase letter-spacing-1">Villes</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <!-- Features End -->"""
c = re.sub(r'<!-- Features Start -->.*?<!-- Features End -->', features_new, c, flags=re.DOTALL)

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(c)

print("Index HTML layout and alignments dramatically improved!")
