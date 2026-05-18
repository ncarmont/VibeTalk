"use client";

import { useEffect, useState } from "react";

function WaveLine({
  text,
  delay = 0,
  purple = false,
  dim = false,
  className = "",
}: {
  text: string;
  delay?: number;
  purple?: boolean;
  dim?: boolean;
  className?: string;
}) {
  const [entered, setEntered] = useState(false);

  useEffect(() => {
    const timer = window.setTimeout(() => setEntered(true), delay);
    return () => window.clearTimeout(timer);
  }, [delay]);

  const chars = text.split("");

  const charStyle = (index: number): React.CSSProperties => {
    const base: React.CSSProperties = {
      display: chars[index] === " " ? "inline" : "inline-block",
      minWidth: chars[index] === " " ? "0.25em" : undefined,
      transition:
        "transform 0.6s cubic-bezier(0.16,1,0.3,1), opacity 0.6s cubic-bezier(0.16,1,0.3,1), filter 0.6s cubic-bezier(0.16,1,0.3,1)",
      transitionDelay: `${index * 25}ms`,
      transform: entered
        ? "translateY(0) scaleY(1)"
        : "translateY(16px) scaleY(3)",
      opacity: entered ? 1 : 0,
      filter: entered ? "blur(0px)" : "blur(6px)",
    };

    if (purple) {
      base.color = "#7359F2";
    }
    if (dim) {
      base.opacity = entered ? 0.3 : 0;
    }

    return base;
  };

  return (
    <span
      className={`block overflow-visible ${className}`}
      style={{ minHeight: "1.2em" }}
    >
      {chars.map((char, index) => (
        <span key={`${char}-${index}`} style={charStyle(index)}>
          {char === " " ? "\u00A0" : char}
        </span>
      ))}
    </span>
  );
}

export default function HeroText() {
  return (
    <h1 className="mb-2 overflow-visible text-4xl font-bold tracking-tight leading-[1.01] sm:text-5xl md:text-5xl">
      <WaveLine text="Vibe code at the" delay={400} />
      <WaveLine text="speed of sound" delay={750} purple />
    </h1>
  );
}
