"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { galleryImages } from "@/lib/site-data";

export function GalleryMasonry() {
  return (
    <section className="py-4">
      <div className="columns-2 gap-3 px-3 md:columns-3 md:gap-4 md:px-4 lg:columns-4">
        {galleryImages.map((img, i) => (
          <motion.div
            key={img.src}
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: (i % 4) * 0.06, duration: 0.5 }}
            className={`mb-3 break-inside-avoid overflow-hidden rounded-2xl md:mb-4 ${img.tall ? "md:mb-4" : ""}`}
          >
            <div className={`group relative w-full overflow-hidden ${img.tall ? "aspect-[3/4]" : "aspect-square"}`}>
              <Image
                src={img.src}
                alt="PayFlex sur le terrain"
                fill
                className="object-cover object-center transition duration-700 group-hover:scale-105"
                sizes="(max-width:768px) 50vw, 25vw"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-[#041c3d]/50 to-transparent opacity-0 transition group-hover:opacity-100" />
            </div>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
