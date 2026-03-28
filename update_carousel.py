import os

css = """
/* --- PREMIUM HERO CAROUSEL --- */
#header-carousel .carousel-item {
    height: 95vh;
    min-height: 600px;
    overflow: hidden;
}
#header-carousel .carousel-item img {
    object-fit: cover;
    height: 100%;
    width: 100%;
    transform: scale(1);
    animation: kenburns 15s ease-out infinite alternate;
}
@keyframes kenburns {
    0% { transform: scale(1); }
    100% { transform: scale(1.15); }
}

#header-carousel .carousel-caption {
    background: linear-gradient(to bottom, rgba(0,0,0,0.8) 0%, rgba(0,0,0,0.2) 50%, rgba(0,0,0,0.8) 100%) !important;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
}

#header-carousel .carousel-control-prev-icon,
#header-carousel .carousel-control-next-icon {
    background-color: rgba(255, 255, 255, 0.1) !important;
    backdrop-filter: blur(8px);
    border: 1px solid rgba(255, 255, 255, 0.3) !important;
    border-radius: 50%;
    width: 60px;
    height: 60px;
    transition: all 0.4s ease;
}
#header-carousel .carousel-control-prev:hover .carousel-control-prev-icon,
#header-carousel .carousel-control-next:hover .carousel-control-next-icon {
    background-color: var(--primary) !important;
    transform: scale(1.15);
    border-color: var(--primary) !important;
    box-shadow: 0 0 25px rgba(3, 96, 236, 0.7);
}

#header-carousel h1.display-1 {
    text-shadow: 2px 4px 10px rgba(0,0,0,0.7);
    font-weight: 800;
}
"""
with open('css/style.css', 'a', encoding='utf-8') as f:
    f.write(css)

with open('index.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('animated slideInRight', 'animated fadeInUp')
content = content.replace('animated slideInDown', 'animated zoomInDown')

with open('index.html', 'w', encoding='utf-8') as f:
    f.write(content)

print("Hero carousel updated with Ken Burns and animations.")
