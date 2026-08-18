"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { ChevronDown, Download, Menu, Moon, Sun, X } from "lucide-react";
import { appConfig, navItems } from "@/lib/site-data";

function isActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  if (href.includes("#")) return pathname === href.split("#")[0];
  return pathname === href || pathname.startsWith(href + "/");
}

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [aboutOpen, setAboutOpen] = useState(false);
  const [dark, setDark] = useState(false);
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem("pf-theme");
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    const isDark = stored === "dark" || (!stored && prefersDark);
    setDark(isDark);
    document.documentElement.classList.toggle("dark", isDark);
  }, []);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const toggleTheme = () => {
    const next = !dark;
    setDark(next);
    document.documentElement.classList.toggle("dark", next);
    localStorage.setItem("pf-theme", next ? "dark" : "light");
  };

  return (
    <header className={`sticky top-0 z-50 glass-nav ${scrolled ? "is-scrolled" : ""}`}>
      <nav className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 lg:px-8">
        <Link href="/" className="relative z-10 shrink-0 transition-opacity hover:opacity-90">
          <Image src="/img/logo.png" alt="PayFlex" width={150} height={52} className="h-10 w-auto md:h-11" priority />
        </Link>

        <button
          type="button"
          className="rounded-xl border border-slate-200/80 p-2.5 text-[var(--foreground)] transition hover:bg-slate-50 dark:border-white/10 dark:hover:bg-white/5 lg:hidden"
          onClick={() => setOpen(!open)}
          aria-label="Menu"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>

        <div
          className={`${
            open ? "flex" : "hidden"
          } nav-panel absolute left-0 right-0 top-full flex-col gap-0.5 border-t p-4 lg:static lg:flex lg:flex-row lg:items-center lg:gap-1 lg:border-0 lg:p-0`}
        >
          {navItems.map((item) => {
            if ("children" in item) {
              const active = item.children.some((c) => isActive(pathname, c.href));
              return (
                <div
                  key={item.label}
                  className="relative lg:group"
                  onMouseEnter={() => setAboutOpen(true)}
                  onMouseLeave={() => setAboutOpen(false)}
                >
                  <button
                    type="button"
                    className={`nav-link ${active ? "is-active" : ""} flex w-full items-center justify-between gap-1 lg:w-auto`}
                    onClick={() => setAboutOpen(!aboutOpen)}
                  >
                    {item.label}
                    <ChevronDown className={`h-4 w-4 transition-transform duration-200 ${aboutOpen ? "rotate-180" : ""}`} />
                  </button>
                  <div
                    className={`${
                      aboutOpen ? "block" : "hidden"
                    } lg:absolute lg:left-0 lg:top-full lg:min-w-[240px] lg:pt-2`}
                  >
                    <div className="nav-dropdown-card flex flex-col gap-0.5">
                      {item.children.map((child) => (
                        <Link
                          key={child.href}
                          href={child.href}
                          className={`nav-dropdown-link ${isActive(pathname, child.href) ? "is-active" : ""}`}
                          onClick={() => {
                            setOpen(false);
                            setAboutOpen(false);
                          }}
                        >
                          {child.label}
                        </Link>
                      ))}
                    </div>
                  </div>
                </div>
              );
            }
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`nav-link ${isActive(pathname, item.href) ? "is-active" : ""}`}
                onClick={() => setOpen(false)}
              >
                {item.label}
              </Link>
            );
          })}

          <div className="mt-2 flex items-center gap-2 lg:mt-0 lg:ml-2">
            <button
              type="button"
              onClick={toggleTheme}
              className="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 text-[var(--foreground)] transition hover:border-[var(--pf-primary)] hover:text-[var(--pf-primary)] dark:border-white/15"
              aria-label="Mode sombre"
            >
              {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </button>
            <Link
              href={appConfig.playStoreUrl}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => setOpen(false)}
              className="btn-pf-primary flex-1 !px-5 !py-2.5 lg:flex-none"
            >
              <Download className="h-4 w-4" />
              Télécharger
            </Link>
          </div>
        </div>
      </nav>
    </header>
  );
}
