import Link from "next/link";

type Crumb = { label: string; href?: string };

export function PageHeader({ title, crumbs }: { title: string; crumbs: Crumb[] }) {
  return (
    <div className="page-header relative">
      <div className="relative z-[1] mx-auto max-w-7xl px-4 py-16 text-center lg:px-6">
        <h1 className="font-display text-4xl font-bold md:text-5xl">{title}</h1>
        <nav className="mt-4 flex flex-wrap items-center justify-center gap-2 text-sm text-white/85">
          {crumbs.map((c, i) => (
            <span key={i} className="flex items-center gap-2">
              {i > 0 && <span>/</span>}
              {c.href ? (
                <Link href={c.href} className="hover:text-[var(--pf-secondary)]">
                  {c.label}
                </Link>
              ) : (
                <span className="text-[var(--pf-secondary)]">{c.label}</span>
              )}
            </span>
          ))}
        </nav>
      </div>
    </div>
  );
}
