import { Reveal } from "@/components/motion/Reveal";

type Props = {
  eyebrow: string;
  title: string;
  description?: string;
  align?: "left" | "center";
};

export function SectionHeader({ eyebrow, title, description, align = "center" }: Props) {
  const alignClass = align === "center" ? "text-center mx-auto" : "text-left";

  return (
    <Reveal className={`mb-14 max-w-2xl ${alignClass}`}>
      <p className="section-title">{eyebrow}</p>
      <h2 className="mt-4 text-3xl font-bold tracking-tight text-slate-900 dark:text-white md:text-4xl">{title}</h2>
      {description && (
        <p className="mt-4 text-base leading-relaxed text-slate-600 dark:text-slate-400">{description}</p>
      )}
    </Reveal>
  );
}
