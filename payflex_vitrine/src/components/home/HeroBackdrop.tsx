"use client";

import Image from "next/image";
import { useEffect, useState } from "react";

const SLIDES = [
  "/img/hero-carousel-mecanique.png",
  "/img/hero-carousel-coiffure.png",
  "/img/hero-carousel-couture.png",
  "/img/hero-carousel-atelier.png",
] as const;

const INTERVAL_MS = 4500;

export function HeroBackdrop() {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const id = window.setInterval(() => {
      setIndex((current) => (current + 1) % SLIDES.length);
    }, INTERVAL_MS);
    return () => window.clearInterval(id);
  }, []);

  return (
    <div className="pointer-events-none absolute inset-0 z-0 overflow-hidden" aria-hidden>
      {SLIDES.map((src, i) => (
        <div
          key={src}
          className="hero-slide absolute inset-0"
          style={{
            opacity: i === index ? 1 : 0,
            transition: "opacity 1.1s cubic-bezier(0.22, 1, 0.36, 1)",
            transitionDuration: "1.1s",
          }}
        >
          <Image
            src={src}
            alt=""
            fill
            priority
            sizes="100vw"
            className="object-cover scale-110 blur-[3px]"
          />
        </div>
      ))}
      <div className="hero-text-scrim absolute inset-0" />
      <div className="absolute inset-0 bg-gradient-to-b from-[var(--background)]/25 via-transparent to-[var(--background)]/85" />
    </div>
  );
}
