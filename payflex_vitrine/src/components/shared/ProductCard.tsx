"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowUpRight } from "lucide-react";
import type { products } from "@/lib/site-data";

type Product = (typeof products)[number];

export function ProductCard({ product }: { product: Product }) {
  return (
    <motion.article
      whileHover={{ y: -6 }}
      transition={{ type: "spring", stiffness: 400, damping: 25 }}
      className="group overflow-hidden rounded-2xl border border-slate-200/80 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900/80"
    >
      <div className="relative aspect-[4/3] overflow-hidden bg-slate-100 dark:bg-slate-800">
        <Image
          src={product.image}
          alt={product.name}
          fill
          className="object-cover object-center transition duration-700 group-hover:scale-105"
          sizes="(max-width:768px) 50vw, 25vw"
        />
        <div className="absolute inset-0 flex items-end justify-end bg-gradient-to-t from-black/50 to-transparent p-4 opacity-0 transition group-hover:opacity-100">
          <Link
            href={`/product/${product.id}`}
            className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-[var(--pf-primary)] shadow-lg"
          >
            <ArrowUpRight className="h-5 w-5" />
          </Link>
        </div>
      </div>
      <div className="p-5">
        <span className="text-xs font-bold uppercase tracking-wider text-[var(--pf-primary)]">{product.category}</span>
        <Link href={`/product/${product.id}`} className="mt-1 block text-lg font-bold tracking-tight hover:text-[var(--pf-primary)]">
          {product.name}
        </Link>
        <p className="mt-2 font-semibold text-[var(--pf-primary)]">{product.monthly}</p>
      </div>
    </motion.article>
  );
}
