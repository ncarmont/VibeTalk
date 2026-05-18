"use client";

import { useEffect, useRef } from "react";

export default function SoundWave() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let animationId: number;
    let time = 0;

    const resize = () => {
      canvas.width = canvas.offsetWidth * 2;
      canvas.height = canvas.offsetHeight * 2;
    };
    resize();
    window.addEventListener("resize", resize);

    const draw = () => {
      time += 0.03;
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      const bars = 48;
      const gap = canvas.width / bars;
      const centerY = canvas.height / 2;

      for (let i = 0; i < bars; i++) {
        const x = i * gap + gap / 2;
        const wave1 = Math.sin(i * 0.3 + time) * 0.5;
        const wave2 = Math.sin(i * 0.15 + time * 1.5) * 0.3;
        const wave3 = Math.sin(i * 0.5 + time * 0.7) * 0.2;
        const amplitude = (wave1 + wave2 + wave3) * centerY * 0.6;
        const height = Math.abs(amplitude) + 4;

        const gradient = ctx.createLinearGradient(x, centerY - height, x, centerY + height);
        gradient.addColorStop(0, "rgba(115, 89, 242, 0.8)");
        gradient.addColorStop(0.5, "rgba(167, 139, 250, 0.6)");
        gradient.addColorStop(1, "rgba(115, 89, 242, 0.8)");

        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.roundRect(x - 2, centerY - height, 4, height * 2, 2);
        ctx.fill();
      }

      animationId = requestAnimationFrame(draw);
    };
    draw();

    return () => {
      cancelAnimationFrame(animationId);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="w-full h-20 sm:h-24"
      style={{ imageRendering: "auto" }}
    />
  );
}
