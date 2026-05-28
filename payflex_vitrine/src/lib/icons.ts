import {
  Award,
  ChartLine,
  GraduationCap,
  Headphones,
  MapPin,
  Package,
  ShieldCheck,
  UserCircle,
  Wallet,
  Wrench,
  type LucideIcon,
} from "lucide-react";

export const statIcons: Record<string, LucideIcon> = {
  users: GraduationCap,
  award: Award,
  userCircle: UserCircle,
  mapPin: MapPin,
};

export const featureIcons: Record<string, LucideIcon> = {
  wallet: Wallet,
  package: Package,
  chart: ChartLine,
  headphones: Headphones,
};

export const aboutIcons = {
  flexibility: Wallet,
  quality: ShieldCheck,
  tools: Wrench,
};
