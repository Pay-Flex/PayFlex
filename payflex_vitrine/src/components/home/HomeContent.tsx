"use client";

import Image from "next/image";
import Link from "next/link";
import { ArrowRight, Check, Headphones, Sparkles, Wallet, Wrench } from "lucide-react";
import { Hero } from "@/components/home/Hero";
import { ImageCollage } from "@/components/home/ImageCollage";
import { GalleryMasonry } from "@/components/home/GalleryMasonry";
import { Reveal } from "@/components/motion/Reveal";
import { SectionHeader } from "@/components/ui/SectionHeader";
import { ProductCard } from "@/components/shared/ProductCard";
import { StatsGrid } from "@/components/shared/StatsGrid";
import { TeamSection } from "@/components/shared/TeamSection";
import { TestimonialsSection } from "@/components/shared/TestimonialsSection";
import { aboutIcons } from "@/lib/icons";
import { products, services, whyChoose } from "@/lib/site-data";
import { featureIcons } from "@/lib/icons";

const serviceIconMap = { tools: Wrench, wallet: Wallet, headphones: Headphones };

export function HomeContent() {
  const featured = products.slice(0, 4);

  return (
    <>
      <Hero />

      <section id="accueil-suite" className="section-spacing -mt-8 pt-4">
        <div className="mx-auto grid max-w-7xl items-center gap-14 px-4 lg:grid-cols-2 lg:px-6">
          <ImageCollage />
          <Reveal direction="right">
            <p className="section-title">À Propos de Nous</p>
            <h2 className="mt-4 text-3xl font-bold tracking-tight md:text-4xl">Découvrez PayFlex et notre mission</h2>
            <p className="mt-5 leading-relaxed text-slate-600 dark:text-slate-400">
              PayFlex est une plateforme numérique conçue pour les jeunes apprentis et artisans, leur permettant
              d&apos;acquérir les outils et kits essentiels grâce à des paiements échelonnés.
            </p>
            <div className="mt-8 grid gap-4 sm:grid-cols-2">
              {[
                { icon: aboutIcons.flexibility, title: "Accessibilité et flexibilité", text: "Payez en plusieurs fois, selon vos revenus." },
                { icon: aboutIcons.quality, title: "Qualité et fiabilité", text: "Des outils et kits certifiés avec garanties." },
              ].map((item) => (
                <div key={item.title} className="flex gap-4 rounded-2xl border border-slate-100 bg-white p-4 dark:border-slate-800 dark:bg-slate-900/50">
                  <div className="icon-box">
                    <item.icon className="h-5 w-5" />
                  </div>
                  <div>
                    <h5 className="font-bold">{item.title}</h5>
                    <p className="mt-1 text-sm text-slate-500">{item.text}</p>
                  </div>
                </div>
              ))}
            </div>
            <Link href="/feature" className="btn-pf-primary mt-8">
              En savoir plus
            </Link>
          </Reveal>
        </div>
      </section>

      <section className="section-spacing bg-slate-50/80 dark:bg-slate-900/30">
        <div className="mx-auto grid max-w-7xl items-center gap-14 px-4 lg:grid-cols-2 lg:px-6">
          <Reveal>
            <p className="section-title">Notre Vision</p>
            <h2 className="mt-4 text-3xl font-bold tracking-tight md:text-4xl">
              Technologie et flexibilité au service des apprentis
            </h2>
            <p className="mt-5 leading-relaxed text-slate-600 dark:text-slate-400">
              Une plateforme intuitive et sécurisée pour vous concentrer sur ce que vous faites de mieux : votre métier.
            </p>
            <div className="mt-8 grid gap-3 sm:grid-cols-2">
              {(
                [
                  ["wallet", "Paiement Mobile Money"],
                  ["package", "Catalogue certifié"],
                  ["chart", "Suivi en direct"],
                  ["headphones", "Support réactif"],
                ] as const
              ).map(([key, label]) => {
                const Icon = featureIcons[key];
                return (
                  <div key={key} className="flex items-center gap-3 rounded-xl bg-white p-3 dark:bg-slate-800/80">
                    <div className="icon-box !h-10 !w-10">
                      <Icon className="h-4 w-4" />
                    </div>
                    <span className="text-sm font-semibold">{label}</span>
                  </div>
                );
              })}
            </div>
          </Reveal>
          <Reveal direction="right" delay={0.15}>
            <div className="relative flex aspect-square max-w-md items-center justify-center overflow-hidden rounded-3xl bg-gradient-to-br from-[var(--pf-primary)] to-[#062849] p-12 shadow-2xl shadow-blue-900/30 mx-auto">
              <div className="absolute inset-0 hero-mesh opacity-60" />
              <Sparkles className="relative h-32 w-32 text-[var(--pf-secondary)] animate-float" strokeWidth={1.2} />
              <div className="absolute bottom-8 left-8 right-8 rounded-2xl border border-white/20 bg-white/10 p-4 backdrop-blur-md">
                <p className="text-sm font-medium text-white/90">Croissance, connexion, autonomie.</p>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      <section className="section-spacing">
        <div className="mx-auto grid max-w-7xl items-center gap-14 px-4 lg:grid-cols-2 lg:px-6">
          <Reveal>
            <p className="section-title">Pourquoi Nous Choisir</p>
            <h2 className="mt-4 text-3xl font-bold tracking-tight md:text-4xl">Les avantages PayFlex pour votre avenir</h2>
            <ul className="mt-8 space-y-3">
              {whyChoose.map((item) => (
                <li
                  key={item}
                  className="flex items-center gap-4 rounded-2xl border border-slate-100 bg-white p-4 dark:border-slate-800 dark:bg-slate-900/50"
                >
                  <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--pf-primary)] text-white">
                    <Check className="h-5 w-5" strokeWidth={2.5} />
                  </span>
                  <span className="font-medium">{item}</span>
                </li>
              ))}
            </ul>
            <Link href="/feature" className="btn-pf-primary mt-8">
              En savoir plus
            </Link>
          </Reveal>
          <StatsGrid />
        </div>
      </section>

      <section className="relative overflow-hidden py-24 text-white">
        <Image src="/img/banner.jpg" alt="" fill className="object-cover" />
        <div className="absolute inset-0 bg-gradient-to-r from-[#041c3d]/95 to-[#0b4a9e]/85" />
        <div className="relative mx-auto grid max-w-7xl gap-10 px-4 md:grid-cols-2 lg:px-6">
          <Reveal>
            <h3 className="text-2xl font-bold md:text-3xl">Des outils de qualité pour votre métier</h3>
            <p className="mt-3 text-white/80">Les meilleurs équipements pour garantir votre succès professionnel.</p>
            <Link href="/catalogue" className="btn-pf-secondary mt-6">
              Voir les produits
            </Link>
          </Reveal>
          <Reveal delay={0.1}>
            <h3 className="text-2xl font-bold md:text-3xl">Un accès simple à l&apos;équipement</h3>
            <p className="mt-3 text-white/80">Un réseau de partenaires locaux à votre service.</p>
            <Link href="/service" className="btn-pf-secondary mt-6">
              Nos services
            </Link>
          </Reveal>
        </div>
      </section>

      <section className="section-spacing">
        <div className="mx-auto max-w-7xl px-4 lg:px-6">
          <SectionHeader
            eyebrow="Nos Services"
            title="Des services conçus pour votre réussite"
            description="De l'acquisition du kit au suivi de vos cotisations, PayFlex vous accompagne."
          />
          <div className="grid gap-6 md:grid-cols-3">
            {services.map((s, i) => {
              const Icon = serviceIconMap[s.icon];
              return (
                <Reveal key={s.title} delay={i * 0.08}>
                  <article className="group premium-card overflow-hidden !p-0">
                    <div className="relative h-52 overflow-hidden">
                      <Image src={s.image} alt={s.title} fill className="object-cover transition duration-700 group-hover:scale-105" />
                      <div className="absolute left-4 top-4 flex h-11 w-11 items-center justify-center rounded-xl bg-white/95 text-[var(--pf-primary)] shadow-lg">
                        <Icon className="h-5 w-5" />
                      </div>
                    </div>
                    <div className="p-6">
                      <h5 className="text-lg font-bold">{s.title}</h5>
                      <p className="mt-2 text-sm leading-relaxed text-slate-500">{s.description}</p>
                      <Link
                        href={s.href}
                        className="mt-4 inline-flex items-center gap-1 text-sm font-bold text-[var(--pf-primary)] transition hover:gap-2"
                      >
                        En savoir plus <ArrowRight className="h-4 w-4" />
                      </Link>
                    </div>
                  </article>
                </Reveal>
              );
            })}
          </div>
        </div>
      </section>

      <div>
        <SectionHeader
          eyebrow="Galerie"
          title="PayFlex sur le terrain"
          description="Apprentis, artisans et équipes en action."
          align="center"
        />
        <GalleryMasonry />
      </div>

      <section className="section-spacing">
        <div className="mx-auto max-w-7xl px-4 lg:px-6">
          <SectionHeader eyebrow="Nos Produits" title="Des kits et outils pour chaque métier" />
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {featured.map((p, i) => (
              <Reveal key={p.id} delay={i * 0.06}>
                <ProductCard product={p} />
              </Reveal>
            ))}
          </div>
          <Reveal className="mt-12 text-center">
            <Link href="/catalogue" className="btn-pf-primary">
              Voir tout le catalogue
            </Link>
          </Reveal>
        </div>
      </section>

      <TeamSection />
      <TestimonialsSection />
    </>
  );
}
