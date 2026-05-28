import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { PageHeader } from "@/components/layout/PageHeader";
import { TeamSection } from "@/components/shared/TeamSection";
import { TestimonialsSection } from "@/components/shared/TestimonialsSection";

export const metadata: Metadata = {
  title: "À Propos",
};

export default function AboutPage() {
  return (
    <>
      <PageHeader
        title="À Propos de Nous"
        crumbs={[
          { label: "Accueil", href: "/" },
          { label: "Pages", href: "/about" },
          { label: "À Propos" },
        ]}
      />
      <section className="py-20">
        <div className="mx-auto grid max-w-7xl items-end gap-12 px-4 lg:grid-cols-2 lg:px-6">
          <div className="grid grid-cols-2 gap-3">
            <div className="relative col-span-1 row-span-2 flex items-center justify-center rounded-2xl bg-[var(--pf-secondary)] p-8">
              <div className="text-center">
                <span className="font-display text-6xl font-bold text-[var(--pf-dark)]">45k</span>
                <p className="mt-2 text-sm font-bold text-[var(--pf-dark)]">Apprentis formés/an</p>
              </div>
            </div>
            <Image src="/img/service-1.jpg" alt="" width={300} height={200} className="rounded-2xl" />
            <Image src="/img/service-2.jpg" alt="" width={300} height={200} className="rounded-2xl" />
            <Image src="/img/service-3.jpg" alt="" width={300} height={200} className="col-span-2 rounded-2xl" />
          </div>
          <div>
            <p className="section-title">À Propos de Nous</p>
            <h2 className="mt-3 text-3xl font-bold">PayFlex : L&apos;autonomie des jeunes artisans</h2>
            <p className="mt-4 text-slate-600 dark:text-slate-400">
              PayFlex est une plateforme numérique d&apos;acquisition d&apos;outils et de kits de travail, conçue
              principalement pour les jeunes apprentis et artisans.
            </p>
            <p className="mt-4 text-slate-600 dark:text-slate-400">
              Au Togo, plus de 45 000 apprentis issus de 57 spécialités professionnelles terminent chaque année leur
              formation sans disposer des ressources nécessaires pour démarrer leur activité. PayFlex permet à ces jeunes
              d&apos;accéder aux équipements indispensables.
            </p>
            <Link href="/contact" className="btn-pf-secondary mt-8">
              Nous Contacter
            </Link>
          </div>
        </div>
      </section>
      <TeamSection id="team" />
      <TestimonialsSection id="testimonials" />
    </>
  );
}
