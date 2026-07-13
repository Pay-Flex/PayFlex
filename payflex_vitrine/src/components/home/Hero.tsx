"use client";

import Image from "next/image";
import Link from "next/link";
import { motion, AnimatePresence, useMotionValue, useSpring } from "framer-motion";
import {
  ArrowRight,
  ChevronDown,
  MapPin,
  ShieldCheck,
  Sparkles,
  Wallet,
  Wrench,
} from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { heroSlides, siteConfig } from "@/lib/site-data";

const TRUST = [
  { icon: Wallet, label: "Mobile Money" },
  { icon: Wrench, label: "57 métiers" },
  { icon: ShieldCheck, label: "Kits certifiés" },
];

const IMPACT = [
  { value: "45k", label: "Apprentis / an" },
  { value: "5", label: "Villes couvertes" },
];

export function Hero() {
  const [index, setIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const mouseX = useMotionValue(0);
  const mouseY = useMotionValue(0);
  const springX = useSpring(mouseX, { stiffness: 80, damping: 20 });
  const springY = useSpring(mouseY, { stiffness: 80, damping: 20 });

  const slide = heroSlides[index];
  const duration = 8000;

  const goTo = useCallback((i: number) => {
    setIndex(i);
    setProgress(0);
  }, []);

  useEffect(() => {
    const start = Date.now();
    const tick = setInterval(() => {
      const elapsed = Date.now() - start;
      const p = Math.min((elapsed / duration) * 100, 100);
      setProgress(p);
      if (p >= 100) {
        setIndex((i) => (i + 1) % heroSlides.length);
        setProgress(0);
      }
    }, 50);
    return () => clearInterval(tick);
  }, [index, duration]);

  const onMouseMove = (e: React.MouseEvent<HTMLElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    mouseX.set((e.clientX - rect.left - rect.width / 2) / 40);
    mouseY.set((e.clientY - rect.top - rect.height / 2) / 40);
  };

  return (
    <section
      className="hero-shell relative min-h-[100svh] overflow-hidden bg-[#030f1f]"
      onMouseMove={onMouseMove}
      data-hero
    >
      {/* Fond atmosphérique */}
      <div className="pointer-events-none absolute inset-0">
        <div className="hero-aurora absolute -left-[20%] top-0 h-[70%] w-[70%] rounded-full opacity-60" />
        <div className="hero-aurora-secondary absolute -right-[10%] bottom-0 h-[50%] w-[50%] rounded-full" />
        <div
          className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage:
              "linear-gradient(rgba(255,255,255,1) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,1) 1px, transparent 1px)",
            backgroundSize: "64px 64px",
          }}
        />
      </div>

      <div className="relative z-10 mx-auto flex min-h-[100svh] max-w-7xl flex-col px-4 pb-28 pt-28 lg:px-8 lg:pt-32">
        <div className="grid flex-1 items-center gap-12 lg:grid-cols-12 lg:gap-8">
          {/* Colonne texte */}
          <div className="lg:col-span-6 xl:col-span-5">
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
              className="mb-8 flex items-center gap-4"
            >
              <div className="relative flex h-14 w-14 items-center justify-center rounded-2xl border border-white/15 bg-white/10 p-2 backdrop-blur-xl">
                <Image src="/img/logo.png" alt="PayFlex" width={48} height={48} className="h-full w-auto object-contain" priority />
                <span className="absolute -right-1 -top-1 flex h-3 w-3">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[var(--pf-secondary)] opacity-60" />
                  <span className="relative inline-flex h-3 w-3 rounded-full bg-[var(--pf-secondary)]" />
                </span>
              </div>
              <div>
                <p className="text-[11px] font-bold uppercase tracking-[0.25em] text-[var(--pf-secondary)]">PayFlex</p>
                <p className="text-sm text-white/60">{siteConfig.tagline}</p>
              </div>
            </motion.div>

            <AnimatePresence mode="wait">
              <motion.div
                key={slide.title}
                initial={{ opacity: 0, y: 28 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -20 }}
                transition={{ duration: 0.55, ease: [0.22, 1, 0.36, 1] }}
              >
                <h1 className="font-display text-[2.75rem] font-bold leading-[1.05] tracking-tight text-white sm:text-5xl lg:text-[3.25rem] xl:text-6xl">
                  <span className="hero-gradient-text block">Équipez-vous.</span>
                  <span className="mt-1 block text-white/95">{slide.title}</span>
                </h1>
                <p className="mt-6 max-w-lg text-base leading-relaxed text-white/65 sm:text-lg">{slide.subtitle}</p>
              </motion.div>
            </AnimatePresence>

            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.2, duration: 0.6 }}
              className="mt-10 flex flex-wrap items-center gap-4"
            >
              <Link href="/catalogue" className="btn-hero-primary group">
                <span>Explorer le catalogue</span>
                <span className="flex h-9 w-9 items-center justify-center rounded-full bg-white/20 transition group-hover:bg-white/30">
                  <ArrowRight className="h-4 w-4 transition group-hover:translate-x-0.5" />
                </span>
              </Link>
              <Link href="/contact" className="btn-hero-outline">
                Nous contacter
              </Link>
            </motion.div>

            <motion.ul
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.35 }}
              className="mt-10 flex flex-wrap gap-3"
            >
              {TRUST.map(({ icon: Icon, label }) => (
                <li
                  key={label}
                  className="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-xs font-semibold text-white/80 backdrop-blur-md"
                >
                  <Icon className="h-3.5 w-3.5 text-[var(--pf-secondary)]" strokeWidth={2.5} />
                  {label}
                </li>
              ))}
            </motion.ul>
          </div>

          {/* Colonne visuelle */}
          <div className="relative lg:col-span-6 xl:col-span-7">
            <motion.div style={{ x: springX, y: springY }} className="relative mx-auto max-w-xl lg:max-w-none">
              {/* Anneau décoratif */}
              <div className="hero-ring pointer-events-none absolute -right-6 -top-6 h-[105%] w-[105%] rounded-[2.5rem] border border-[var(--pf-secondary)]/20" />
              <div className="hero-ring-delayed pointer-events-none absolute -bottom-4 -left-4 h-[95%] w-[95%] rounded-[2.5rem] border border-white/10" />

              {/* Image principale */}
              <div className="hero-visual-frame relative aspect-[4/5] overflow-hidden rounded-[2rem] shadow-2xl shadow-black/50 sm:aspect-[5/6]">
                <AnimatePresence mode="wait">
                  {heroSlides.map(
                    (s, i) =>
                      i === index && (
                        <motion.div
                          key={s.image}
                          initial={{ opacity: 0, scale: 1.06 }}
                          animate={{ opacity: 1, scale: 1 }}
                          exit={{ opacity: 0 }}
                          transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
                          className="absolute inset-0"
                        >
                          <Image
                            src={s.image}
                            alt=""
                            fill
                            priority
                            className="object-cover object-center"
                            sizes="(max-width:1024px) 100vw, 50vw"
                          />
                        </motion.div>
                      )
                  )}
                </AnimatePresence>
                <div className="absolute inset-0 bg-gradient-to-t from-[#030f1f]/80 via-transparent to-transparent" />
                <div className="absolute inset-0 bg-gradient-to-r from-[#030f1f]/30 to-transparent" />

                {/* Shine */}
                <div className="hero-shine pointer-events-none absolute inset-0" />
              </div>

              {/* Carte flottante — cotisation */}
              <motion.div
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.5, duration: 0.6 }}
                className="absolute -left-2 top-[12%] z-20 max-w-[200px] rounded-2xl border border-white/15 bg-white/10 p-4 backdrop-blur-xl sm:-left-8"
              >
                <div className="flex items-center gap-2 text-[var(--pf-secondary)]">
                  <Sparkles className="h-4 w-4" />
                  <span className="text-[10px] font-bold uppercase tracking-wider">Flexible</span>
                </div>
                <p className="mt-2 text-2xl font-bold text-white">3 000 XOF</p>
                <p className="text-xs text-white/60">par mois et par métier</p>
              </motion.div>

              {/* Carte flottante — impact */}
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.65, duration: 0.6 }}
                className="absolute -bottom-4 -right-2 z-20 rounded-2xl border border-white/15 bg-[var(--pf-primary)]/90 p-4 shadow-xl backdrop-blur-xl sm:-right-6 sm:bottom-6"
              >
                <div className="flex gap-6">
                  {IMPACT.map((item) => (
                    <div key={item.label}>
                      <p className="text-2xl font-bold text-white">{item.value}</p>
                      <p className="text-[10px] font-medium uppercase tracking-wide text-white/70">{item.label}</p>
                    </div>
                  ))}
                </div>
              </motion.div>

              {/* Badge localisation */}
              <div className="absolute right-4 top-4 z-20 flex items-center gap-2 rounded-full border border-white/20 bg-black/30 px-3 py-1.5 text-xs font-semibold text-white backdrop-blur-md">
                <MapPin className="h-3.5 w-3.5 text-[var(--pf-secondary)]" />
                Lomé, Togo
              </div>
            </motion.div>
          </div>
        </div>

        {/* Contrôles slides */}
        <div className="mt-10 flex flex-col gap-6 border-t border-white/10 pt-8 sm:flex-row sm:items-end sm:justify-between">
          <div className="flex gap-3">
            {heroSlides.map((s, i) => (
              <button
                key={s.image}
                type="button"
                onClick={() => goTo(i)}
                className={`group relative h-16 w-24 overflow-hidden rounded-xl border-2 transition-all duration-300 sm:h-[72px] sm:w-28 ${
                  i === index
                    ? "border-[var(--pf-secondary)] shadow-lg shadow-amber-500/20"
                    : "border-white/10 opacity-50 hover:border-white/30 hover:opacity-80"
                }`}
                aria-label={`Slide ${i + 1}`}
              >
                <Image src={s.image} alt="" fill className="object-cover" sizes="112px" />
                {i === index && (
                  <div
                    className="absolute bottom-0 left-0 h-0.5 bg-[var(--pf-secondary)] transition-[width] duration-75 ease-linear"
                    style={{ width: `${progress}%` }}
                  />
                )}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-6">
            <div className="hidden h-px flex-1 bg-white/10 sm:block sm:min-w-[120px]" />
            <p className="text-xs font-medium tabular-nums text-white/40">
              {String(index + 1).padStart(2, "0")} / {String(heroSlides.length).padStart(2, "0")}
            </p>
          </div>
        </div>
      </div>

      {/* Scroll indicator */}
      <motion.a
        href="#accueil-suite"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.2 }}
        className="absolute bottom-8 left-1/2 z-20 flex -translate-x-1/2 flex-col items-center gap-2 text-white/40 transition hover:text-white/70"
        aria-label="Défiler vers le contenu"
      >
        <span className="text-[10px] font-semibold uppercase tracking-widest">Découvrir</span>
        <ChevronDown className="h-5 w-5 animate-bounce" />
      </motion.a>

      {/* Vague de transition */}
      <div className="hero-wave pointer-events-none absolute -bottom-px left-0 right-0 z-10 text-white dark:text-[var(--background)]">
        <svg viewBox="0 0 1440 120" fill="currentColor" preserveAspectRatio="none" className="block h-16 w-full md:h-24">
          <path d="M0,64 C360,120 720,0 1080,48 C1260,72 1380,96 1440,80 L1440,120 L0,120 Z" />
        </svg>
      </div>
    </section>
  );
}
