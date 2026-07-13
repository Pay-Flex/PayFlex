"use client";

import { motion, AnimatePresence } from "framer-motion";
import { Quote } from "lucide-react";
import { useEffect, useState } from "react";
import { Reveal } from "@/components/motion/Reveal";
import { SectionHeader } from "@/components/ui/SectionHeader";
import { testimonials } from "@/lib/site-data";

export function TestimonialsSection({ id }: { id?: string }) {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const t = setInterval(() => setIndex((i) => (i + 1) % testimonials.length), 5500);
    return () => clearInterval(t);
  }, []);

  const t = testimonials[index];

  return (
    <section id={id} className="section-spacing">
      <div className="mx-auto max-w-7xl px-4 lg:px-6">
        <SectionHeader
          eyebrow="Témoignages"
          title="Ce que nos utilisateurs pensent de PayFlex"
          align="center"
        />
        <Reveal>
          <div className="relative mx-auto max-w-3xl overflow-hidden rounded-3xl border border-slate-200/80 bg-white p-10 shadow-xl dark:border-slate-800 dark:bg-slate-900/80 md:p-14">
            <Quote className="mx-auto mb-6 h-10 w-10 text-[var(--pf-primary)]" strokeWidth={1.5} />
            <AnimatePresence mode="wait">
              <motion.div
                key={t.name}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                transition={{ duration: 0.4 }}
                className="text-center"
              >
                <p className="text-lg italic leading-relaxed text-slate-600 dark:text-slate-300">&ldquo;{t.text}&rdquo;</p>
                <h5 className="mt-8 text-lg font-bold">{t.name}</h5>
                <span className="text-sm font-semibold uppercase tracking-wide text-[var(--pf-primary)]">{t.role}</span>
              </motion.div>
            </AnimatePresence>
            <div className="mt-8 flex justify-center gap-2">
              {testimonials.map((_, i) => (
                <button
                  key={i}
                  type="button"
                  className={`h-1.5 rounded-full transition-all duration-300 ${
                    i === index ? "w-8 bg-[var(--pf-primary)]" : "w-2 bg-slate-300 hover:bg-slate-400"
                  }`}
                  onClick={() => setIndex(i)}
                  aria-label={`Témoignage ${i + 1}`}
                />
              ))}
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
