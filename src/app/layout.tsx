import type { Metadata } from "next";
import Script from "next/script";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL("https://vibe-talk.fun"),
  title: "VibeTalk — Vibe code at the speed of sound and vision",
  description:
    "Free, private, on-device voice-to-text and screenshot context for macOS. Compare speaking versus typing, then use VibeTalk to move faster with sound and vision.",
  openGraph: {
    title: "VibeTalk — Vibe code at the speed of sound and vision",
    description:
      "Free, private, on-device voice-to-text and screenshot context for macOS. Put speaking versus typing to the test.",
    type: "website",
    url: "https://vibe-talk.fun",
    siteName: "VibeTalk",
  },
  twitter: {
    card: "summary_large_image",
    title: "VibeTalk — Vibe code at the speed of sound and vision",
    description:
      "Free, private, on-device voice-to-text and screenshot context for macOS.",
  },
  icons: {
    icon: "/icon.png",
    apple: "/icon.png",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <head>
        <Script
          async
          src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-1361556625262612"
          crossOrigin="anonymous"
          strategy="afterInteractive"
        />
      </head>
      <body className="antialiased">{children}</body>
    </html>
  );
}
