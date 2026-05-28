import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { PageHeader } from "@/components/layout/PageHeader";
import { ProductCard } from "@/components/shared/ProductCard";
import { getProductById, products } from "@/lib/site-data";

type Props = { params: Promise<{ id: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { id } = await params;
  const product = getProductById(id);
  return { title: product?.name ?? "Produit" };
}

export default async function ProductPage({ params }: Props) {
  const { id } = await params;
  const product = getProductById(id);
  if (!product) notFound();

  const related = products.filter((p) => p.category === product.category && p.id !== product.id).slice(0, 3);

  return (
    <>
      <PageHeader
        title={product.name}
        crumbs={[
          { label: "Accueil", href: "/" },
          { label: "Catalogue", href: "/catalogue" },
          { label: product.name },
        ]}
      />
      <section className="py-20">
        <div className="mx-auto grid max-w-7xl gap-12 px-4 lg:grid-cols-2 lg:px-6">
          <div className="relative aspect-square overflow-hidden rounded-3xl shadow-xl">
            <Image src={product.image} alt={product.name} fill className="object-cover" priority />
          </div>
          <div>
            <span className="rounded-full bg-[var(--pf-primary)]/10 px-4 py-1 text-sm font-bold text-[var(--pf-primary)]">
              {product.category}
            </span>
            <h2 className="mt-4 text-3xl font-bold">{product.name}</h2>
            <p className="mt-4 text-slate-600 dark:text-slate-400">{product.description}</p>
            <div className="mt-8 space-y-2">
              <p>
                <span className="font-semibold">Prix :</span> {product.price}
              </p>
              <p className="text-xl font-bold text-[var(--pf-primary)]">{product.monthly}</p>
            </div>
            <p className="mt-6 text-sm text-slate-500">
              Cotisez via l&apos;application mobile PayFlex et recevez votre kit une fois le montant atteint.
            </p>
            <Link href="/contact" className="btn-pf-primary mt-8">
              Demander des informations
            </Link>
          </div>
        </div>
        {related.length > 0 && (
          <div className="mx-auto mt-20 max-w-7xl px-4 lg:px-6">
            <h3 className="mb-8 text-2xl font-bold">Produits similaires</h3>
            <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {related.map((p) => (
                <ProductCard key={p.id} product={p} />
              ))}
            </div>
          </div>
        )}
      </section>
    </>
  );
}
