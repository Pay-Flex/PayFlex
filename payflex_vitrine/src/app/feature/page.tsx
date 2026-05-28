import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { Check, ChartLine, Headphones, Package, Wallet } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { StatsGrid } from "@/components/shared/StatsGrid";
import { TeamSection } from "@/components/shared/TeamSection";
import { TestimonialsSection } from "@/components/shared/TestimonialsSection";
import { featureBlocks, whyChoose } from "@/lib/site-data";

export const metadata: Metadata = {
  title: "Fonctionnalités",
};

const icons = { wallet: Wallet, package: Package, chart: ChartLine, headphones: Headphones };

export default function FeaturePage() {
  return (
    <>
      <PageHeader
        title="Nos Avantages"
        crumbs={[
          { label: "Accueil", href: "/" },
          { label: "Pages", href: "/feature" },
          { label: "Avantages" },
        ]}
      />
      <section className="py-20">
        <div className="mx-auto grid max-w-7xl items-end gap-12 px-4 lg:grid-cols-2 lg:px-6">
          <div className="grid grid-cols-2 gap-3">
            <div className="flex items-center justify-center rounded-2xl bg-[var(--pf-secondary)] p-8">
              <div className="text-center">
                <span className="font-display text-6xl font-bold">45k</span>
                <p className="text-sm font-bold">Apprentis formés/an</p>
              </div>
            </div>
            {[1, 2, 3].map((n) => (
              <Image key={n} src={`/img/service-${n}.jpg`} alt="" width={300} height={200} className="rounded-2xl" />
            ))}
          </div>
          <div>
            <p className="section-title">À Propos de Nous</p>
            <h2 className="mt-3 text-3xl font-bold">PayFlex : L&apos;autonomie des jeunes artisans</h2>
            <p className="mt-4 text-slate-600">
              Plateforme d&apos;acquisition d&apos;outils avec paiement échelonné pour les apprentis et artisans du Togo.
            </p>
            <Link href="/contact" className="btn-pf-secondary mt-8">
              Nous Contacter
            </Link>
          </div>
        </div>
      </section>

      <section id="features" className="bg-slate-50 py-20 dark:bg-slate-900/40">
        <div className="mx-auto max-w-7xl px-4 lg:px-6">
          <div className="mb-12 grid gap-6 md:grid-cols-2 lg:grid-cols-4">
            {featureBlocks.map((f) => {
              const Icon = icons[f.icon as keyof typeof icons];
              return (
                <div key={f.title} className="premium-card text-center">
                  <Icon className="mx-auto mb-4 h-10 w-10 text-[var(--pf-primary)]" />
                  <h5 className="font-bold">{f.title}</h5>
                  <p className="mt-2 text-sm text-slate-500">{f.description}</p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      <section className="py-20">
        <div className="mx-auto grid max-w-7xl items-center gap-12 px-4 lg:grid-cols-2 lg:px-6">
          <div>
            <p className="section-title">Pourquoi Nous Choisir !</p>
            <h2 className="mt-3 text-3xl font-bold">Les avantages de PayFlex pour votre avenir</h2>
            <ul className="mt-6 space-y-3">
              {whyChoose.map((item) => (
                <li key={item} className="flex items-center gap-2">
                  <Check className="h-5 w-5 text-[var(--pf-primary)]" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
          <StatsGrid />
        </div>
      </section>

      <TestimonialsSection id="testimonials" />
      <TeamSection id="team" />
    </>
  );
}
