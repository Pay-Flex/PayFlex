import Image from "next/image";
import { Reveal } from "@/components/motion/Reveal";

export function ImageCollage() {
  return (
    <Reveal direction="left">
      <div className="grid grid-cols-2 grid-rows-[auto_auto_auto] gap-3 md:gap-4">
        <div className="relative row-span-2 min-h-[300px] overflow-hidden rounded-2xl shadow-lg md:min-h-[360px]">
          <Image src="/img/service-1.jpg" alt="" fill className="object-cover object-center transition duration-700 hover:scale-105" sizes="(max-width:768px) 50vw, 25vw" />
        </div>
        <div className="relative min-h-[140px] overflow-hidden rounded-2xl shadow-lg md:min-h-[170px]">
          <Image src="/img/service-2.jpg" alt="" fill className="object-cover object-center transition duration-700 hover:scale-105" sizes="25vw" />
        </div>
        <div className="relative min-h-[140px] overflow-hidden rounded-2xl shadow-lg md:min-h-[170px]">
          <Image src="/img/service-3.jpg" alt="" fill className="object-cover object-center transition duration-700 hover:scale-105" sizes="25vw" />
        </div>
        <div className="flex min-h-[120px] flex-col items-center justify-center rounded-2xl bg-gradient-to-br from-[var(--pf-secondary)] to-[#e8a825] p-6 shadow-lg">
          <span className="font-display text-5xl font-bold text-[var(--pf-dark)]">+57</span>
          <span className="mt-2 text-center text-xs font-bold uppercase tracking-widest text-[var(--pf-dark)]/80">spécialités</span>
        </div>
      </div>
    </Reveal>
  );
}
