"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, ShieldCheck, Sparkles, Star, Wallet, Wrench } from "lucide-react";
import { PlayStoreButton } from "@/components/shared/PlayStoreButton";
import { HeroBackdrop } from "@/components/home/HeroBackdrop";
import { appConfig } from "@/lib/site-data";

const TRUST = [
  { icon: Wallet, label: "Mobile Money" },
  { icon: Wrench, label: "57 métiers" },
  { icon: ShieldCheck, label: "Kits certifiés" },
];

const ease = [0.22, 1, 0.36, 1] as const;

export function Hero() {
  return (
    <section className="relative overflow-hidden" data-hero>
      <HeroBackdrop />
      {/* Décor doux */}
      <div className="pointer-events-none absolute inset-0 z-[1]">
        <div className="blob animate-blob absolute -left-24 -top-24 h-96 w-96 rounded-full bg-[var(--pf-primary)]/25" />
        <div className="blob animate-blob absolute -right-16 top-24 h-80 w-80 rounded-full bg-[var(--pf-secondary)]/25" />
        <div
          className="absolute inset-0 opacity-[0.04]"
          style={{
            backgroundImage:
              "linear-gradient(var(--pf-primary) 1px, transparent 1px), linear-gradient(90deg, var(--pf-primary) 1px, transparent 1px)",
            backgroundSize: "56px 56px",
            maskImage: "radial-gradient(ellipse 70% 60% at 50% 30%, black, transparent)",
            WebkitMaskImage: "radial-gradient(ellipse 70% 60% at 50% 30%, black, transparent)",
          }}
        />
      </div>

      <div className="relative z-10 mx-auto grid max-w-7xl items-center gap-12 px-4 pb-16 pt-14 lg:grid-cols-2 lg:gap-8 lg:px-8 lg:pb-24 lg:pt-20">
        {/* Colonne texte */}
        <div>
          <motion.div
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease }}
          >
            <span className="eyebrow">
              <Sparkles className="h-3.5 w-3.5" />
              Avec PayFlex
            </span>
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease, delay: 0.05 }}
            className="mt-6 font-display text-4xl font-bold leading-[1.08] tracking-tight text-[var(--foreground)] sm:text-5xl lg:text-6xl"
          >
            Équipez-vous.{" "}
            <span className="accent-underline">
              <span className="gradient-text">Cotisez à votre rythme.</span>
            </span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease, delay: 0.12 }}
            className="mt-6 max-w-xl text-lg leading-relaxed text-[var(--pf-muted)]"
          >
            PayFlex permet aux apprentis et artisans du Togo d&apos;acquérir leurs outils
            professionnels grâce à un paiement échelonné via Mobile Money. Simple, flexible et
            accompagné.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease, delay: 0.2 }}
            className="mt-9 flex flex-wrap items-center gap-4"
          >
            <PlayStoreButton />
            <Link href="/catalogue" className="btn-pf-outline group">
              Voir le catalogue
              <ArrowRight className="h-4 w-4 transition group-hover:translate-x-0.5" />
            </Link>
          </motion.div>

          {/* Preuve sociale */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.7, delay: 0.3 }}
            className="mt-8 flex flex-wrap items-center gap-x-8 gap-y-4"
          >
            <div className="flex items-center gap-3">
              <div className="flex">
                {[0, 1, 2, 3, 4].map((i) => (
                  <Star key={i} className="h-4 w-4 fill-[var(--pf-secondary)] text-[var(--pf-secondary)]" />
                ))}
              </div>
              <p className="text-sm font-semibold text-[var(--foreground)]">
                {appConfig.rating}
                <span className="font-normal text-[var(--pf-muted)]"> · {appConfig.reviews} avis</span>
              </p>
            </div>
            <div className="h-8 w-px bg-slate-200 dark:bg-white/10" />
            <p className="text-sm font-semibold text-[var(--foreground)]">
              {appConfig.downloads}
              <span className="font-normal text-[var(--pf-muted)]"> téléchargements</span>
            </p>
          </motion.div>

          <motion.ul
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.7, delay: 0.4 }}
            className="mt-8 flex flex-wrap gap-2.5"
          >
            {TRUST.map(({ icon: Icon, label }) => (
              <li key={label} className="pill">
                <Icon className="h-3.5 w-3.5 text-[var(--pf-primary)] dark:text-[var(--pf-secondary)]" strokeWidth={2.5} />
                {label}
              </li>
            ))}
          </motion.ul>
        </div>

        {/* Colonne visuelle — mockup app */}
        <motion.div
          initial={{ opacity: 0, scale: 0.94, y: 24 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ duration: 0.9, ease }}
          className="relative mx-auto w-full max-w-md lg:max-w-none"
        >
          <div className="relative">
            {/* Halo */}
            <div className="absolute inset-x-6 top-6 -z-10 h-full rounded-[3rem] bg-gradient-to-b from-[var(--pf-primary)]/15 to-transparent blur-2xl" />

            <div className="relative mx-auto aspect-[3/4] w-full max-w-sm overflow-hidden rounded-[2.5rem]">
              <Image
                src="/img/app-hero-phone.png"
                alt="Application mobile PayFlex : tableau de bord des cotisations"
                fill
                priority
                className="object-contain drop-shadow-2xl"
                sizes="(max-width:1024px) 80vw, 40vw"
              />
            </div>

            {/* Carte flottante — cotisation */}
            <motion.div
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.5, duration: 0.6 }}
              className="animate-float absolute -left-2 top-16 z-20 w-44 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-xl backdrop-blur dark:border-white/10 dark:bg-white/10 sm:-left-6"
            >
              <div className="flex items-center gap-2 text-[var(--pf-primary)] dark:text-[var(--pf-secondary)]">
                <Wallet className="h-4 w-4" />
                <span className="text-[10px] font-bold uppercase tracking-wider">Cotisation</span>
              </div>
              <p className="mt-2 text-2xl font-bold text-[var(--foreground)]">3 000 XOF</p>
              <p className="text-xs text-[var(--pf-muted)]">par mois et par métier</p>
            </motion.div>

            {/* Carte flottante — objectif */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.65, duration: 0.6 }}
              className="animate-float-slow absolute -right-2 bottom-16 z-20 w-40 rounded-2xl border border-slate-200/70 bg-white/90 p-4 shadow-xl backdrop-blur dark:border-white/10 dark:bg-white/10 sm:-right-6"
            >
              <p className="text-[10px] font-bold uppercase tracking-wider text-[var(--pf-muted)]">Objectif atteint</p>
              <p className="mt-1 text-2xl font-bold text-[var(--pf-primary)] dark:text-[var(--pf-secondary)]">68%</p>
              <div className="mt-2 h-1.5 w-full overflow-hidden rounded-full bg-slate-100 dark:bg-white/10">
                <div className="h-full w-[68%] rounded-full bg-gradient-to-r from-[var(--pf-primary)] to-[var(--pf-secondary)]" />
              </div>
            </motion.div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
