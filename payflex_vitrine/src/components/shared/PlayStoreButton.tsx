import Link from "next/link";
import { appConfig } from "@/lib/site-data";

function PlayIcon({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 512 512" className={className} aria-hidden="true">
      <path fill="#00d0ff" d="M47 24.6c-6 4.2-9.5 11.4-9.5 20.7v421.4c0 9.3 3.5 16.5 9.5 20.7L280 256 47 24.6z" />
      <path fill="#00e676" d="M370 176.5 280 256 47 24.6c2-1.4 4.3-2.3 6.7-2.6 6.2-.8 13.4 1 20.9 5.3L370 176.5z" />
      <path fill="#ff3d47" d="M370 335.5 74.6 484.7c-7.5 4.3-14.7 6.1-20.9 5.3-2.4-.3-4.7-1.2-6.7-2.6L280 256l90 79.5z" />
      <path fill="#ffc400" d="M471.4 229.3c13.2 7.4 20.6 17.3 20.6 26.7s-7.4 19.3-20.6 26.7l-101.4 52.8L280 256l90-79.5 101.4 52.8z" />
    </svg>
  );
}

type Props = { variant?: "dark" | "light"; className?: string };

export function PlayStoreButton({ variant = "dark", className = "" }: Props) {
  const isLight = variant === "light";
  return (
    <Link
      href={appConfig.playStoreUrl}
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Télécharger PayFlex sur Google Play"
      className={`group inline-flex items-center gap-3 rounded-2xl px-5 py-3 transition-all duration-300 hover:-translate-y-0.5 ${
        isLight
          ? "border border-white/25 bg-white text-[#0b1f3a] shadow-[0_16px_40px_-18px_rgba(11,31,58,0.45)] hover:border-transparent hover:bg-[var(--pf-secondary)]"
          : "bg-[var(--pf-dark)] text-white shadow-[0_16px_40px_-16px_rgba(11,31,58,0.7)] hover:bg-[#0f2547]"
      } ${className}`}
    >
      <PlayIcon className="h-7 w-7 shrink-0 transition-transform duration-300 group-hover:scale-110" />
      <span className={`leading-tight ${isLight ? "text-[#0b1f3a]" : "text-white"}`}>
        <span className="block text-[10px] font-medium uppercase tracking-wide opacity-70">Disponible sur</span>
        <span className="block text-base font-bold tracking-tight">Google Play</span>
      </span>
    </Link>
  );
}
