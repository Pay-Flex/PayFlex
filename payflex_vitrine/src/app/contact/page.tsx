"use client";

import type { FormEvent } from "react";
import { Mail, MapPin, Phone } from "lucide-react";
import { PageHeader } from "@/components/layout/PageHeader";
import { siteConfig } from "@/lib/site-data";

export default function ContactPage() {
  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    alert("Merci ! Votre message a été enregistré (démo vitrine).");
  }

  return (
    <>
      <PageHeader
        title="Contactez-nous"
        crumbs={[
          { label: "Accueil", href: "/" },
          { label: "Pages", href: "/contact" },
          { label: "Contact" },
        ]}
      />
      <section className="py-20">
        <div className="mx-auto max-w-7xl px-4 lg:px-6">
          <div className="mb-12 text-center">
            <p className="section-title">Contactez-nous</p>
            <h2 className="mt-3 text-3xl font-bold">Une question ? Écrivez-nous</h2>
          </div>
          <div className="grid gap-10 lg:grid-cols-2">
            <div className="space-y-6">
              <div className="premium-card flex gap-4">
                <MapPin className="h-6 w-6 shrink-0 text-[var(--pf-primary)]" />
                <div>
                  <h5 className="font-bold">Adresse</h5>
                  <p className="text-sm text-slate-500">{siteConfig.address}</p>
                </div>
              </div>
              <div className="premium-card flex gap-4">
                <Phone className="h-6 w-6 shrink-0 text-[var(--pf-primary)]" />
                <div>
                  <h5 className="font-bold">Téléphone</h5>
                  <p className="text-sm text-slate-500">{siteConfig.phoneDisplay}</p>
                </div>
              </div>
              <div className="premium-card flex gap-4">
                <Mail className="h-6 w-6 shrink-0 text-[var(--pf-primary)]" />
                <div>
                  <h5 className="font-bold">Email</h5>
                  <p className="text-sm text-slate-500">{siteConfig.email}</p>
                </div>
              </div>
              <div className="overflow-hidden rounded-3xl">
                <iframe
                  title="Carte Lomé"
                  className="h-64 w-full border-0"
                  src="https://www.google.com/maps/embed?pb=!1m18!1m12!1m3!1d253682.462!2d1.2!3d6.1!2m3!1f0!2f0!3f0!3m2!1i1024!2i768!4f13.1!3m3!1m2!1s0x0%3A0x0!2zNsKwMDcnMDAuMCJOIDHCsDEyJzAwLjAiRQ!5e0!3m2!1sfr!2stg!4v1"
                  loading="lazy"
                />
              </div>
            </div>
            <form onSubmit={handleSubmit} className="premium-card space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <input required placeholder="Prénom" className="rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-[var(--pf-primary)] dark:border-slate-600 dark:bg-slate-900" />
                <input required placeholder="Nom" className="rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-[var(--pf-primary)] dark:border-slate-600 dark:bg-slate-900" />
              </div>
              <input type="email" required placeholder="Email" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-[var(--pf-primary)] dark:border-slate-600 dark:bg-slate-900" />
              <input placeholder="Sujet" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-[var(--pf-primary)] dark:border-slate-600 dark:bg-slate-900" />
              <textarea required rows={5} placeholder="Message" className="w-full rounded-xl border border-slate-200 px-4 py-3 text-sm outline-none focus:border-[var(--pf-primary)] dark:border-slate-600 dark:bg-slate-900" />
              <button type="submit" className="btn-pf-primary w-full sm:w-auto">
                Envoyer le message
              </button>
            </form>
          </div>
        </div>
      </section>
    </>
  );
}
