import type { Metadata } from "next";
import { Libre_Baskerville, Open_Sans } from "next/font/google";
import { Topbar } from "@/components/layout/Topbar";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { BackToTop } from "@/components/layout/BackToTop";
import "./globals.css";

const openSans = Open_Sans({
  subsets: ["latin"],
  variable: "--font-open-sans",
});

const libre = Libre_Baskerville({
  weight: "700",
  subsets: ["latin"],
  variable: "--font-libre",
});

export const metadata: Metadata = {
  title: {
    default: "PayFlex — Cotisation progressive pour artisans",
    template: "%s | PayFlex",
  },
  description:
    "PayFlex permet aux apprentis et artisans d'acquérir leurs outils professionnels grâce à un paiement échelonné flexible.",
  icons: { icon: "/img/pflex.jpeg" },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fr" suppressHydrationWarning>
      <body className={`${openSans.variable} ${libre.variable} antialiased`}>
        <Topbar />
        <Navbar />
        <main>{children}</main>
        <Footer />
        <BackToTop />
      </body>
    </html>
  );
}
