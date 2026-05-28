"use client";

import { Globe, Phone, Share2 } from "lucide-react";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { siteConfig } from "@/lib/site-data";

export function Topbar() {
  const pathname = usePathname();
  const isHome = pathname === "/";
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 48);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  if (isHome && !scrolled) return null;

  return (
    <div className="hidden border-b border-slate-200/60 bg-[var(--pf-secondary)] lg:block dark:border-slate-800">
      <div className="mx-auto flex max-w-7xl items-stretch justify-between">
        <div className="flex items-center gap-3 px-6 py-2 text-xs font-semibold text-[var(--pf-dark)]">
          <span className="opacity-80">Suivez-nous</span>
          {[Share2, Globe].map((Icon, i) => (
            <a
              key={i}
              href="#"
              className="flex h-7 w-7 items-center justify-center rounded-full bg-[var(--pf-dark)]/10 transition hover:bg-[var(--pf-dark)]/20"
              aria-label="Réseau social"
            >
              <Icon className="h-3.5 w-3.5" />
            </a>
          ))}
        </div>
        <div className="flex items-center gap-2 bg-[var(--pf-primary)] px-6 py-2 text-xs font-semibold text-white">
          <Phone className="h-3.5 w-3.5" />
          <span className="opacity-90">Appelez-nous :</span>
          <a href={`tel:${siteConfig.phone.replace(/\s/g, "")}`} className="hover:underline">
            {siteConfig.phone}
          </a>
        </div>
      </div>
    </div>
  );
}
