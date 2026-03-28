import re
import glob

new_team_html = """<!-- Team Start -->
    <div class="container-xxl py-5" id="team">
        <div class="container">
            <div class="text-center mx-auto wow fadeInUp" data-wow-delay="0.1s" style="max-width: 500px;">
                <p class="section-title bg-white text-center text-primary px-3">Notre Équipe</p>
                <h1 class="mb-5">Membres de l'équipe</h1>
            </div>
            <div class="row g-4">
                <div class="col-lg-3 col-md-6 wow fadeInUp" data-wow-delay="0.1s">
                    <div class="team-item rounded p-4 h-100 d-flex flex-column justify-content-center text-center">
                        <div class="bg-light rounded-circle d-flex align-items-center justify-content-center mx-auto mb-4" style="width: 100px; height: 100px; border: 3px solid var(--primary);">
                            <i class="fas fa-user-tie fa-3x text-primary"></i>
                        </div>
                        <h5 class="mb-2">HIBA Divine</h5>
                        <p class="text-primary mb-1 fw-bold">Chef Projet et Founder</p>
                        <p class="small text-muted mb-3">Spécialiste en Transformation Digitale</p>
                        <div class="d-flex justify-content-center mt-auto">
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-facebook-f"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-twitter"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-linkedin-in"></i></a>
                        </div>
                    </div>
                </div>
                <div class="col-lg-3 col-md-6 wow fadeInUp" data-wow-delay="0.3s">
                    <div class="team-item rounded p-4 h-100 d-flex flex-column justify-content-center text-center">
                        <div class="bg-light rounded-circle d-flex align-items-center justify-content-center mx-auto mb-4" style="width: 100px; height: 100px; border: 3px solid var(--primary);">
                            <i class="fas fa-laptop-code fa-3x text-primary"></i>
                        </div>
                        <h5 class="mb-2">Chaminade Dondah ADJOLOU</h5>
                        <p class="text-primary mb-1 fw-bold">Developpeur Web et Mobile</p>
                        <p class="small text-muted mb-3">Co-Founder</p>
                        <div class="d-flex justify-content-center mt-auto">
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-facebook-f"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-twitter"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-linkedin-in"></i></a>
                        </div>
                    </div>
                </div>
                <div class="col-lg-3 col-md-6 wow fadeInUp" data-wow-delay="0.5s">
                    <div class="team-item rounded p-4 h-100 d-flex flex-column justify-content-center text-center">
                        <div class="bg-light rounded-circle d-flex align-items-center justify-content-center mx-auto mb-4" style="width: 100px; height: 100px; border: 3px solid var(--primary);">
                            <i class="fas fa-user fa-3x text-primary"></i>
                        </div>
                        <h5 class="mb-2">John Doe</h5>
                        <p class="text-primary mb-1 fw-bold">Membre de l'équipe</p>
                        <p class="small text-muted mb-3"></p>
                        <div class="d-flex justify-content-center mt-auto">
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-facebook-f"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-twitter"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-linkedin-in"></i></a>
                        </div>
                    </div>
                </div>
                <div class="col-lg-3 col-md-6 wow fadeInUp" data-wow-delay="0.7s">
                    <div class="team-item rounded p-4 h-100 d-flex flex-column justify-content-center text-center">
                        <div class="bg-light rounded-circle d-flex align-items-center justify-content-center mx-auto mb-4" style="width: 100px; height: 100px; border: 3px solid var(--primary);">
                            <i class="fas fa-user fa-3x text-primary"></i>
                        </div>
                        <h5 class="mb-2">John Doe</h5>
                        <p class="text-primary mb-1 fw-bold">Membre de l'équipe</p>
                        <p class="small text-muted mb-3"></p>
                        <div class="d-flex justify-content-center mt-auto">
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-facebook-f"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-twitter"></i></a>
                            <a class="btn btn-square btn-outline-secondary rounded-circle mx-1" href="#"><i class="fab fa-linkedin-in"></i></a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <!-- Team End -->"""

html_files = glob.glob('*.html')
for file in html_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if '<!-- Team Start -->' in content:
        new_content = re.sub(r'<!-- Team Start -->.*?<!-- Team End -->', new_team_html, content, flags=re.DOTALL)
        with open(file, 'w', encoding='utf-8') as f:
            f.write(new_content)

print('Team section updated successfully with icons!')
