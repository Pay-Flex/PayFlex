"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { ChevronDown, Menu, Moon, Sun, X } from "lucide-react";
import { navItems } from "@/lib/site-data";

function isActive(pathname: string, href: string) {
  if (href === "/") return pathname === "/";
  if (href.includes("#")) return pathname === href.split("#")[0];
  return pathname === href || pathname.startsWith(href + "/");
}

export function Navbar() {
  const pathname = usePathname();
  const isHome = pathname === "/";
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
    const onScroll = () => setScrolled(window.scrollY > 48);
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

  const overlay = isHome && !scrolled;
  const linkClass = (active: boolean) =>
    `nav-link ${overlay ? "nav-link-hero" : ""} ${active ? "is-active" : ""}`;
  const dropdownClass = (active: boolean) =>
    `nav-dropdown-link ${overlay ? "nav-dropdown-link-hero" : ""} ${active ? "is-active" : ""}`;

  return (
    <header
      className={`z-50 transition-all duration-500 ${
        overlay
          ? "absolute inset-x-0 top-0 border-transparent bg-transparent"
          : `sticky top-0 glass-nav ${scrolled ? "is-scrolled" : ""}`
      }`}
    >
      <nav className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-3 lg:px-8">
        <Link href="/" className="relative z-10 shrink-0 transition-opacity hover:opacity-90">
          <Image
            src="/img/logo.png"
            alt="PayFlex"
            width={150}
            height={52}
            className={`h-11 w-auto transition md:h-12 ${overlay ? "brightness-0 invert" : ""}`}
            priority
          />
        </Link>

        <button
          type="button"
          className={`rounded-xl border p-2.5 transition lg:hidden ${
            overlay
              ? "border-white/20 text-white hover:bg-white/10"
              : "border-slate-200/80 text-slate-700 hover:bg-slate-50 dark:border-slate-700 dark:text-slate-200"
          }`}
          onClick={() => setOpen(!open)}
          aria-label="Menu"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>

        <div
          className={`${
            open ? "flex" : "hidden"
          } absolute left-0 right-0 top-full flex-col gap-0.5 border-t p-4 backdrop-blur-2xl lg:static lg:flex lg:flex-row lg:items-center lg:gap-1 lg:border-0 lg:bg-transparent lg:p-0 ${
            overlay
              ? "border-white/10 bg-[#030f1f]/95"
              : "border-slate-200/80 bg-white/95 dark:border-slate-800 dark:bg-slate-950/95 lg:dark:bg-transparent"
          }`}
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
                    className={`${linkClass(active)} flex w-full items-center justify-between gap-1 lg:w-auto`}
                    onClick={() => setAboutOpen(!aboutOpen)}
                  >
                    {item.label}
                    <ChevronDown className={`h-4 w-4 transition-transform duration-200 ${aboutOpen ? "rotate-180" : ""}`} />
                  </button>
                  <div
                    className={`${
                      aboutOpen ? "block" : "hidden"
                    } lg:absolute lg:left-0 lg:top-full lg:mt-2 lg:block lg:min-w-[240px] lg:rounded-2xl lg:border lg:p-2 lg:shadow-xl ${
                      overlay
                        ? "lg:border-white/10 lg:bg-[#0a2540]/95 lg:shadow-black/40"
                        : "lg:border-slate-200/80 lg:bg-white lg:shadow-slate-900/10 dark:lg:border-slate-700 dark:lg:bg-slate-900"
                    }`}
                  >
                    {item.children.map((child) => (
                      <Link
                        key={child.href}
                        href={child.href}
                        className={dropdownClass(isActive(pathname, child.href))}
                        onClick={() => setOpen(false)}
                      >
                        {child.label}
                      </Link>
                    ))}
                  </div>
                </div>
              );
            }
            return (
              <Link
                key={item.href}
                href={item.href}
                className={linkClass(isActive(pathname, item.href))}
                onClick={() => setOpen(false)}
              >
                {item.label}
              </Link>
            );
          })}
          <button
            type="button"
            onClick={toggleTheme}
            className={`mx-2 mt-2 flex h-10 w-10 items-center justify-center rounded-full border transition lg:mx-0 lg:mt-0 ${
              overlay
                ? "border-white/25 text-white hover:bg-white/10"
                : "border-slate-200 text-slate-600 hover:border-[var(--pf-primary)] hover:text-[var(--pf-primary)] dark:border-slate-600"
            }`}
            aria-label="Mode sombre"
          >
            {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </button>
        </div>
      </nav>
    </header>
  );
}
