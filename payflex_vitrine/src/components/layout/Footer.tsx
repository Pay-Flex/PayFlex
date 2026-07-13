import Image from "next/image";
import Link from "next/link";
import { siteConfig } from "@/lib/site-data";
import { Globe, Mail, MapPin, Phone, Share2 } from "lucide-react";

export function Footer() {
  return (
    <>
      <footer className="mt-20 bg-gradient-to-br from-[#062849] via-[var(--pf-primary)] to-[#0a3d7a] text-white">
        <div className="mx-auto max-w-7xl px-4 py-14 lg:px-6">
          <div className="mb-12 flex flex-col items-start gap-4 border-b border-white/10 pb-10 md:flex-row md:items-center md:justify-between">
            <Image src="/img/logo.png" alt="PayFlex" width={160} height={56} className="h-14 w-auto brightness-0 invert" />
            <p className="max-w-md text-sm text-white/70">{siteConfig.tagline} — Cotisation progressive pour artisans et apprentis au Togo.</p>
          </div>
          <div className="grid gap-10 md:grid-cols-2 lg:grid-cols-4">
            <div>
              <h5 className="mb-4 text-lg font-bold">Notre Bureau</h5>
              <p className="mb-2 flex items-start gap-2 text-sm text-white/80">
                <MapPin className="mt-0.5 h-4 w-4 shrink-0" />
                {siteConfig.address}
              </p>
              <p className="mb-2 flex items-center gap-2 text-sm text-white/80">
                <Phone className="h-4 w-4" />
                {siteConfig.phoneDisplay}
              </p>
              <p className="flex items-center gap-2 text-sm text-white/80">
                <Mail className="h-4 w-4" />
                {siteConfig.email}
              </p>
              <div className="mt-4 flex gap-2">
                {[Share2, Globe, Share2, Globe].map((Icon, i) => (
                  <a
                    key={i}
                    href="#"
                    className="flex h-9 w-9 items-center justify-center rounded-full bg-[var(--pf-secondary)] text-[var(--pf-dark)] transition hover:scale-110"
                  >
                    <Icon className="h-4 w-4" />
                  </a>
                ))}
              </div>
            </div>
            <div>
              <h5 className="mb-4 text-lg font-bold">Liens Rapides</h5>
              <div className="flex flex-col gap-2 text-sm">
                <Link href="/about" className="text-white/80 hover:text-[var(--pf-secondary)]">
                  À Propos de Nous
                </Link>
                <Link href="/contact" className="text-white/80 hover:text-[var(--pf-secondary)]">
                  Contactez-nous
                </Link>
                <Link href="/service" className="text-white/80 hover:text-[var(--pf-secondary)]">
                  Nos Services
                </Link>
                <Link href="/feature" className="text-white/80 hover:text-[var(--pf-secondary)]">
                  Termes & Conditions
                </Link>
                <Link href="/feature" className="text-white/80 hover:text-[var(--pf-secondary)]">
                  Support
                </Link>
              </div>
            </div>
            <div>
              <h5 className="mb-4 text-lg font-bold">Horaires</h5>
              <div className="space-y-3 text-sm text-white/80">
                <div>
                  <p>Lundi - Vendredi</p>
                  <p className="font-semibold text-white">09:00 - 19:00</p>
                </div>
                <div>
                  <p>Samedi</p>
                  <p className="font-semibold text-white">09:00 - 12:00</p>
                </div>
                <div>
                  <p>Dimanche</p>
                  <p className="font-semibold text-white">Fermé</p>
                </div>
              </div>
            </div>
            <div>
              <h5 className="mb-4 text-lg font-bold">Newsletter</h5>
              <p className="mb-4 text-sm text-white/80">
                Inscrivez-vous pour recevoir les dernières actualités PayFlex.
              </p>
              <div className="relative">
                <input
                  type="email"
                  placeholder="Votre email"
                  className="w-full rounded-full border border-white/20 bg-white/10 py-3 pl-4 pr-28 text-sm text-white placeholder:text-white/50 outline-none focus:border-[var(--pf-secondary)]"
                />
                <button type="button" className="absolute right-1 top-1 rounded-full bg-[var(--pf-secondary)] px-4 py-2 text-xs font-bold text-[var(--pf-dark)]">
                  S&apos;inscrire
                </button>
              </div>
            </div>
          </div>
        </div>
      </footer>
      <div className="border-t border-white/10 bg-[#041c3d] py-4 text-center text-sm text-white/70">
        <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-2 px-4 md:flex-row">
          <span>
            © {new Date().getFullYear()} {siteConfig.name}, Tous Droits Réservés.
          </span>
          <span>
            Designed By{" "}
            <a href="https://donchaminade-alpha.vercel.app" className="font-semibold text-[var(--pf-secondary)] hover:underline">
              PayFlex
            </a>
          </span>
        </div>
      </div>
    </>
  );
}
