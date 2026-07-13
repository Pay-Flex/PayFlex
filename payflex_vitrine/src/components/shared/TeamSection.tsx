"use client";

import { Code2, User, UserRound } from "lucide-react";
import { Reveal } from "@/components/motion/Reveal";
import { SectionHeader } from "@/components/ui/SectionHeader";
import { team } from "@/lib/site-data";

const icons = { tie: UserRound, code: Code2, user: User };

export function TeamSection({ id }: { id?: string }) {
  return (
    <section id={id} className="section-spacing bg-slate-50/80 dark:bg-slate-900/30">
      <div className="mx-auto max-w-7xl px-4 lg:px-6">
        <SectionHeader eyebrow="Notre Équipe" title="Membres de l'équipe" align="center" />
        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {team.map((m, i) => {
            const Icon = icons[m.icon as keyof typeof icons] ?? User;
            return (
              <Reveal key={`${m.name}-${i}`} delay={i * 0.08}>
                <div className="premium-card flex flex-col items-center text-center">
                  <div className="mb-4 flex h-20 w-20 items-center justify-center rounded-2xl border-2 border-[var(--pf-primary)]/20 bg-[var(--pf-primary)]/5">
                    <Icon className="h-9 w-9 text-[var(--pf-primary)]" strokeWidth={1.5} />
                  </div>
                  <h5 className="text-lg font-bold">{m.name}</h5>
                  <p className="text-sm font-semibold text-[var(--pf-primary)]">{m.role}</p>
                  {m.bio && <p className="mt-2 text-sm text-slate-500">{m.bio}</p>}
                </div>
              </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}
