import Image from "next/image";
import Link from "next/link";
import type { Metadata } from "next";
import { ChevronRight } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { services } from "@/lib/site-data";

export const metadata: Metadata = {
  title: "Services",
};

export default function ServicePage() {
  return (
    <>
      <PageHeader
        title="Nos Services"
        crumbs={[
          { label: "Accueil", href: "/" },
          { label: "Pages", href: "/service" },
          { label: "Services" },
        ]}
      />
      <section className="py-20">
        <div className="mx-auto max-w-7xl px-4 lg:px-6">
          <div className="mb-12 text-center">
            <p className="section-title">Nos Services</p>
            <h2 className="mt-3 text-3xl font-bold">Des services conçus pour votre réussite</h2>
            <p className="mx-auto mt-4 max-w-2xl text-slate-600">
              PayFlex centralise l&apos;accès aux outils professionnels et simplifie le paiement pour chaque métier.
            </p>
          </div>
          <div className="space-y-8">
            {services.map((s, i) => (
              <div
                key={s.title}
                className={`flex flex-col gap-6 overflow-hidden rounded-3xl bg-white shadow-xl md:flex-row ${
                  i % 2 === 1 ? "md:flex-row-reverse" : ""
                } dark:bg-slate-800`}
              >
                <div className="relative h-64 md:h-auto md:w-2/5">
                  <Image src={s.image} alt={s.title} fill className="object-cover" />
                </div>
                <div className="flex flex-1 flex-col justify-center p-8">
                  <h3 className="text-2xl font-bold">{s.title}</h3>
                  <p className="mt-3 text-slate-600 dark:text-slate-400">{s.description}</p>
                  <Link
                    href={s.href}
                    className="mt-6 inline-flex items-center gap-2 font-bold text-[var(--pf-primary)] hover:underline"
                  >
                    En savoir plus <ChevronRight className="h-4 w-4" />
                  </Link>
                </div>
              </div>
            ))}
          </div>
          <div className="mt-16 rounded-3xl bg-gradient-to-r from-[var(--pf-primary)] to-[#062849] p-10 text-center text-white">
            <h3 className="text-2xl font-bold">Prêt à démarrer avec PayFlex ?</h3>
            <p className="mt-2 text-white/80">Téléchargez l&apos;application mobile ou contactez notre équipe.</p>
            <Link href="/contact" className="btn-pf-secondary mt-6">
              Nous contacter
            </Link>
          </div>
        </div>
      </section>
    </>
  );
}
