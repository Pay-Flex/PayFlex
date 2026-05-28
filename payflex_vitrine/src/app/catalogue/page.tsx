"use client";

import { useMemo, useState } from "react";
import { PageHeader } from "@/components/layout/PageHeader";
import { ProductCard } from "@/components/shared/ProductCard";
import { getCategories, products } from "@/lib/site-data";

export default function CataloguePage() {
  const categories = getCategories();
  const [filter, setFilter] = useState("Tous");

  const filtered = useMemo(
    () => (filter === "Tous" ? products : products.filter((p) => p.category === filter)),
    [filter]
  );

  return (
    <>
      <PageHeader
        title="Catalogue"
        crumbs={[
          { label: "Accueil", href: "/" },
          { label: "Pages", href: "/catalogue" },
          { label: "Catalogue" },
        ]}
      />
      <section className="py-20">
        <div className="mx-auto max-w-7xl px-4 lg:px-6">
          <div className="mb-10 text-center">
            <p className="section-title">Nos Produits</p>
            <h2 className="mt-3 text-3xl font-bold">Catalogue des kits et outils</h2>
          </div>
          <div className="mb-10 flex flex-wrap justify-center gap-2">
            {categories.map((cat) => (
              <button
                key={cat}
                type="button"
                onClick={() => setFilter(cat)}
                className={`rounded-full px-5 py-2 text-sm font-semibold transition ${
                  filter === cat
                    ? "bg-[var(--pf-primary)] text-white"
                    : "bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-slate-800 dark:text-slate-300"
                }`}
              >
                {cat}
              </button>
            ))}
          </div>
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {filtered.map((p) => (
              <ProductCard key={p.id} product={p} />
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
