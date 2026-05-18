"use client";

import { useEffect, useRef } from "react";

export default function AnimatedBackground() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let animationId: number;
    let time = 0;
    let dpr = 1;

    const resize = () => {
      const cssWidth = window.innerWidth;
      const cssHeight = document.documentElement.scrollHeight;
      const rawDpr = Math.min(window.devicePixelRatio || 1, 2);
      const maxPixels = 12_000_000;
      dpr = Math.max(
        0.75,
        Math.min(rawDpr, Math.sqrt(maxPixels / Math.max(1, cssWidth * cssHeight)))
      );

      canvas.width = Math.ceil(cssWidth * dpr);
      canvas.height = Math.ceil(cssHeight * dpr);
      canvas.style.width = cssWidth + "px";
      canvas.style.height = cssHeight + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    window.addEventListener("resize", resize);

    const W = () => canvas.width / dpr;
    const H = () => canvas.height / dpr;

    // Soft orbs
    const orbs = [
      { x: 0.3, y: 0.08, r: 350, color: [115, 89, 242], speed: 0.0003 },
      { x: 0.7, y: 0.06, r: 300, color: [167, 139, 250], speed: 0.0005 },
      { x: 0.5, y: 0.25, r: 280, color: [99, 102, 241], speed: 0.0004 },
      { x: 0.2, y: 0.45, r: 220, color: [139, 92, 246], speed: 0.0006 },
      { x: 0.8, y: 0.4, r: 240, color: [115, 89, 242], speed: 0.0003 },
      { x: 0.5, y: 0.65, r: 260, color: [79, 70, 229], speed: 0.0005 },
    ];

    // Audio wave configs — multiple layers for depth
    const waves = [
      { y: 0.18, amplitude: 25, frequency: 0.008, speed: 0.015, alpha: 0.04, width: 1.5 },
      { y: 0.18, amplitude: 18, frequency: 0.012, speed: -0.02, alpha: 0.03, width: 1 },
      { y: 0.18, amplitude: 30, frequency: 0.006, speed: 0.01, alpha: 0.025, width: 2 },
      { y: 0.40, amplitude: 20, frequency: 0.01, speed: 0.018, alpha: 0.03, width: 1.5 },
      { y: 0.40, amplitude: 15, frequency: 0.015, speed: -0.012, alpha: 0.025, width: 1 },
      { y: 0.60, amplitude: 22, frequency: 0.009, speed: 0.014, alpha: 0.03, width: 1.5 },
      { y: 0.60, amplitude: 16, frequency: 0.013, speed: -0.016, alpha: 0.02, width: 1 },
      { y: 0.80, amplitude: 18, frequency: 0.011, speed: 0.02, alpha: 0.025, width: 1.5 },
    ];

    let paused = false;
    const onVisibility = () => { paused = document.hidden; };
    document.addEventListener("visibilitychange", onVisibility);

    const draw = () => {
      if (paused) { animationId = requestAnimationFrame(draw); return; }
      time++;
      const w = W();
      const h = H();
      ctx.clearRect(0, 0, w, h);

      // Draw orbs
      for (const orb of orbs) {
        const cx = (orb.x + Math.sin(time * orb.speed) * 0.08) * w;
        const cy = (orb.y + Math.cos(time * orb.speed * 1.3) * 0.04) * h;
        const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, orb.r);
        gradient.addColorStop(0, `rgba(${orb.color.join(",")},0.1)`);
        gradient.addColorStop(0.5, `rgba(${orb.color.join(",")},0.04)`);
        gradient.addColorStop(1, `rgba(${orb.color.join(",")},0)`);
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, w, h);
      }

      // Draw audio waves
      for (const wave of waves) {
        const baseY = wave.y * h;
        ctx.beginPath();
        ctx.moveTo(0, baseY);

        for (let x = 0; x <= w; x += 2) {
          const y =
            baseY +
            Math.sin(x * wave.frequency + time * wave.speed) * wave.amplitude +
            Math.sin(x * wave.frequency * 2.3 + time * wave.speed * 1.7) *
              (wave.amplitude * 0.3);
          ctx.lineTo(x, y);
        }

        ctx.strokeStyle = `rgba(115, 89, 242, ${wave.alpha})`;
        ctx.lineWidth = wave.width;
        ctx.stroke();
      }

      // Draw floating particles that pulse like audio dots
      const particleCount = 30;
      for (let i = 0; i < particleCount; i++) {
        const seed = i * 137.508;
        const px =
          (((Math.sin(seed) * 0.5 + 0.5) * w +
            Math.sin(time * 0.002 + seed) * 40) %
            w);
        const py =
          (((Math.cos(seed * 0.7) * 0.5 + 0.5) * h +
            Math.cos(time * 0.0015 + seed) * 30) %
            h);
        const pulse =
          Math.sin(time * 0.03 + i * 0.5) * 0.5 + 0.5;
        const radius = 1.5 + pulse * 2;
        const alpha = 0.05 + pulse * 0.08;

        ctx.beginPath();
        ctx.arc(px, py, radius, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(167, 139, 250, ${alpha})`;
        ctx.fill();
      }

      animationId = requestAnimationFrame(draw);
    };
    draw();

    return () => {
      cancelAnimationFrame(animationId);
      window.removeEventListener("resize", resize);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="absolute top-0 left-0 pointer-events-none z-0"
      style={{ opacity: 0.8 }}
    />
  );
}
