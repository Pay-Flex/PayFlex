export const siteConfig = {
  name: "PayFlex",
  tagline: "L'innovation à votre portée",
  phone: "+228 345 6789",
  phoneDisplay: "+228 90 00 00 00",
  email: "contact@payflex.com",
  address: "123 Rue de l'avenir, Lomé, Togo",
};

export const navItems = [
  { href: "/", label: "Accueil" },
  {
    label: "À Propos",
    children: [
      { href: "/about", label: "À Propos de Nous" },
      { href: "/feature", label: "Fonctionnalités" },
      { href: "/about#team", label: "Notre Équipe" },
      { href: "/about#testimonials", label: "Témoignages" },
    ],
  },
  { href: "/service", label: "Services" },
  { href: "/catalogue", label: "Catalogue" },
  { href: "/contact", label: "Contact" },
] as const;

/** Photos réelles uniquement — pas de mockups téléphone / app */
export const heroSlides = [
  {
    image: "/img/carousel-1.jpg",
    title: "La solution pour tous les apprentis",
    subtitle: "Cotisez progressivement et équipez-vous pour démarrer votre métier.",
    align: "start" as const,
  },
  {
    image: "/img/banner.jpg",
    title: "Votre avenir professionnel commence ici",
    subtitle: "Outils certifiés, paiement flexible, accompagnement de proximité.",
    align: "start" as const,
  },
  {
    image: "/img/images/WhatsApp Image 2026-04-07 at 18.39.55.jpeg",
    title: "PayFlex, au cœur du terrain",
    subtitle: "Des artisans togolais qui construisent leur autonomie jour après jour.",
    align: "start" as const,
  },
];

export const services = [
  {
    title: "Acquisition d'outils et de kits",
    description:
      "Accédez à une large gamme d'outils et de kits de travail de qualité, sélectionnés auprès de fournisseurs locaux fiables.",
    image: "/img/service-1.jpg",
    href: "/service",
    icon: "tools" as const,
  },
  {
    title: "Paiement échelonné et flexible",
    description:
      "Payez à votre rythme grâce au Mobile Money et acquérez vos équipements sans pression financière.",
    image: "/img/service-2.jpg",
    href: "/service",
    icon: "wallet" as const,
  },
  {
    title: "Accompagnement et support",
    description:
      "Conseils personnalisés et support client accessible pour une expérience simple et fiable.",
    image: "/img/service-3.jpg",
    href: "/contact",
    icon: "headphones" as const,
  },
];

export const products = [
  { id: "1", slug: "kit-demarrage-mecanique", name: "Kit de Démarrage Mécanique", category: "Mécanique", price: "150 000 FCFA", monthly: "À partir de 5000 XOF/mois", image: "/img/product-mech.png", description: "L'essentiel pour tout mécanicien débutant avec des outils de précision." },
  { id: "2", slug: "kit-coiffure-pro", name: "Kit de Coiffure Professionnel", category: "Coiffure", price: "120 000 FCFA", monthly: "À partir de 3000 XOF/mois", image: "/img/product-hair.jpg", description: "Tondeuses, ciseaux et accessoires de qualité pour salons modernes." },
  { id: "3", slug: "machine-coudre-creative", name: "Machine à Coudre Créative", category: "Couture", price: "250 000 FCFA", monthly: "À partir de 4000 XOF/mois", image: "/img/product-sew.png", description: "Idéale pour les créations complexes et robustes sur tous tissus." },
  { id: "4", slug: "outils-plomberie", name: "Ensemble d'Outils de Plomberie", category: "Plomberie", price: "180 000 FCFA", monthly: "À partir de 4500 XOF/mois", image: "/img/product-plumb.jpg", description: "Tout le nécessaire pour les installations et réparations sanitaires." },
  { id: "5", slug: "diagnostic-auto", name: "Mallette de Diagnostic Auto", category: "Mécanique", price: "350 000 FCFA", monthly: "Sur devis", image: "/img/product-mech.png", description: "Valise de diagnostic électronique multimarque haute précision." },
  { id: "6", slug: "casque-sechage", name: "Casque de Séchage sur Pied", category: "Coiffure", price: "95 000 FCFA", monthly: "Sur devis", image: "/img/product-hair.jpg", description: "Séchage rapide et homogène en milieu professionnel." },
  { id: "7", slug: "surjeteuse-pro", name: "Surjeteuse Professionnelle", category: "Couture", price: "320 000 FCFA", monthly: "Sur devis", image: "/img/product-sew.png", description: "Finitions impeccables pour tous vos ouvrages de couture." },
  { id: "8", slug: "kit-solaire", name: "Kit Énergie Solaire", category: "Solaire", price: "450 000 FCFA", monthly: "Sur devis", image: "/img/gallery-ai-4.png", description: "Panneaux et onduleur pour une autonomie énergétique durable." },
];

export const team = [
  { name: "HIBA Divine", role: "Chef Projet et Founder", bio: "Economiste & Spécialiste en Transformation Digitale", icon: "tie" },
  { name: "Chaminade Dondah ADJOLOU", role: "Developpeur Web et Mobile", bio: "Co-Founder", icon: "code" },
  { name: "John Doe", role: "Membre de l'équipe", bio: "", icon: "user" },
  { name: "John Doe", role: "Membre de l'équipe", bio: "", icon: "user" },
];

export const testimonials = [
  { name: "Afi", role: "Apprentie coiffeuse • Lomé", text: "Grâce à PayFlex, j'ai enfin pu acheter mon propre kit de coiffure. Le paiement en plusieurs fois m'a vraiment aidé à démarrer mon activité sans stress." },
  { name: "Kodjo", role: "Artisan mécanicien • Kara", text: "Je recommande PayFlex à tous les jeunes artisans. La plateforme est simple à utiliser et les outils sont de très bonne qualité." },
  { name: "Esinam", role: "Apprentie couturière • Sokodé", text: "Le support client est très réactif. On se sent vraiment accompagné." },
];

export const stats = [
  { value: "45000", label: "Apprentis", icon: "users", color: "primary" },
  { value: "15", label: "Partenaires", icon: "award", color: "secondary" },
  { value: "30000", label: "Utilisateurs", icon: "userCircle", color: "info" },
  { value: "5", label: "Villes", icon: "mapPin", color: "success" },
];

export function getProductById(id: string) {
  return products.find((p) => p.id === id || p.slug === id);
}

export function getCategories() {
  return ["Tous", ...Array.from(new Set(products.map((p) => p.category)))];
}

export const whyChoose = [
  "Accompagnement et conseils personnalisés",
  "Services complémentaires (maintenance, location, etc.)",
  "Une communauté de professionnels pour échanger",
];

/** Galerie terrain — sans mockups app / téléphone */
export const galleryImages = [
  { src: "/img/images/WhatsApp Image 2026-04-07 at 18.39.55.jpeg", tall: true },
  { src: "/img/images/WhatsApp Image 2026-04-07 at 18.39.57.jpeg", tall: false },
  { src: "/img/service-1.jpg", tall: false },
  { src: "/img/images/WhatsApp Image 2026-04-07 at 18.39.56 (1).jpeg", tall: true },
  { src: "/img/service-2.jpg", tall: false },
  { src: "/img/images/WhatsApp Image 2026-04-07 at 18.39.57 (1).jpeg", tall: false },
  { src: "/img/service-3.jpg", tall: true },
  { src: "/img/gallery-ai-5.png", tall: false },
];

export const featureBlocks = [
  {
    title: "Paiement échelonné",
    description: "Payez à votre rythme via Mobile Money et acquérez vos outils sans pression.",
    icon: "wallet",
  },
  {
    title: "Catalogue certifié",
    description: "Des kits et équipements sélectionnés auprès de fournisseurs locaux fiables.",
    icon: "package",
  },
  {
    title: "Suivi en temps réel",
    description: "Visualisez vos cotisations et l'avancement vers l'acquisition de votre kit.",
    icon: "chart",
  },
  {
    title: "Support dédié",
    description: "Une équipe à votre écoute pour vous accompagner à chaque étape.",
    icon: "headphones",
  },
];
