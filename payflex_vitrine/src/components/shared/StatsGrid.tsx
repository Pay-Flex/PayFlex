"use client";

import { motion } from "framer-motion";
import { statIcons } from "@/lib/icons";
import { stats } from "@/lib/site-data";

const accents: Record<string, { border: string; icon: string; text: string }> = {
  primary: {
    border: "border-[var(--pf-primary)]",
    icon: "bg-[var(--pf-primary)]/10 text-[var(--pf-primary)]",
    text: "text-[var(--pf-primary)]",
  },
  secondary: {
    border: "border-[var(--pf-secondary)]",
    icon: "bg-[var(--pf-secondary)]/20 text-amber-700 dark:text-[var(--pf-secondary)]",
    text: "text-amber-600 dark:text-[var(--pf-secondary)]",
  },
  info: {
    border: "border-cyan-500",
    icon: "bg-cyan-500/10 text-cyan-600",
    text: "text-cyan-600",
  },
  success: {
    border: "border-emerald-500",
    icon: "bg-emerald-500/10 text-emerald-600",
    text: "text-emerald-600",
  },
};

export function StatsGrid() {
  return (
    <div className="grid gap-4 sm:grid-cols-2">
      {stats.map((s, i) => {
        const Icon = statIcons[s.icon] ?? statIcons.users;
        const a = accents[s.color] ?? accents.primary;
        return (
          <motion.div
            key={s.label}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.08, duration: 0.5 }}
            className={`premium-card border-t-4 ${a.border}`}
          >
            <div className={`icon-box mb-4 ${a.icon}`}>
              <Icon className="h-6 w-6" strokeWidth={2} />
            </div>
            <h3 className={`text-4xl font-bold tracking-tight ${a.text}`}>{s.value}</h3>
            <span className="mt-1 block text-sm font-semibold uppercase tracking-wide text-slate-500">{s.label}</span>
          </motion.div>
        );
      })}
    </div>
  );
}
