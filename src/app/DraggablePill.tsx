"use client";

import { useRef, useState, useCallback, useEffect } from "react";

export default function DraggablePill() {
  const pillRef = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [dragging, setDragging] = useState(false);
  const [imageTrayOpen, setImageTrayOpen] = useState(false);
  const dragStart = useRef({ x: 0, y: 0 });
  const posStart = useRef({ x: 0, y: 0 });

  const onPointerDown = useCallback(
    (e: React.PointerEvent) => {
      if ((e.target as HTMLElement).closest("[data-pill-action]")) {
        return;
      }

      setDragging(true);
      dragStart.current = { x: e.clientX, y: e.clientY };
      posStart.current = { x: pos.x, y: pos.y };
      (e.target as HTMLElement).setPointerCapture(e.pointerId);
    },
    [pos]
  );

  const onPointerMove = useCallback(
    (e: React.PointerEvent) => {
      if (!dragging) return;
      setPos({
        x: posStart.current.x + (e.clientX - dragStart.current.x),
        y: posStart.current.y + (e.clientY - dragStart.current.y),
      });
    },
    [dragging]
  );

  const onPointerUp = useCallback(() => {
    setDragging(false);
  }, []);

  return (
    <section className="relative z-10 px-8 py-16 text-center">
      <p className="text-sm text-white/30 mb-6">
        The vibe coding toolbar that lets you easily record and drag and drop screenshots
      </p>
      <div className="relative inline-block">
        {imageTrayOpen && (
        <div className="absolute right-0 -top-[118px] z-20 hidden w-[342px] rounded-[14px] border border-[#7359F2]/30 bg-[#111117]/95 p-4 text-left shadow-[0_18px_60px_rgba(0,0,0,0.45)] sm:block">
          <div className="mb-3 text-xs font-semibold text-white/80">
            Drag and drop images to the AI chat
          </div>
          <div className="flex items-center gap-2">
            {[
              "from-[#7359F2] via-[#A78BFA] to-[#111117]",
              "from-[#1D4ED8] via-[#22D3EE] to-[#0F172A]",
              "from-[#16A34A] via-[#FACC15] to-[#111117]",
            ].map((gradient, index) => (
              <div
                key={gradient}
                className={`relative h-16 w-[78px] overflow-hidden rounded-lg border border-white/10 bg-gradient-to-br ${gradient}`}
              >
                <div className="absolute inset-x-2 bottom-2 h-2 rounded-full bg-black/25" />
                <div className="absolute right-2 top-2 h-4 w-6 rounded bg-white/25" />
                {index === 0 ? (
                  <span className="absolute left-1.5 top-1.5 rounded-full bg-[#7359F2] px-2 py-0.5 text-[9px] font-semibold text-white">
                    latest
                  </span>
                ) : null}
              </div>
            ))}
            <div className="ml-1 flex h-7 w-7 items-center justify-center rounded-full bg-[#7359F2]/40 text-white">
              <svg
                width="13"
                height="13"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="m9 18 6-6-6-6" />
              </svg>
            </div>
          </div>
        </div>
        )}
        <div
          ref={pillRef}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          style={{
            transform: `translate(${pos.x}px, ${pos.y}px)`,
            cursor: dragging ? "grabbing" : "grab",
            touchAction: "none",
            userSelect: "none",
          }}
          className="inline-flex items-center gap-2 pl-2 pr-3 py-2 rounded-full bg-[#111117] border border-white/[0.06] shadow-[0_8px_32px_rgba(0,0,0,0.4)] transition-shadow hover:shadow-[0_8px_32px_rgba(115,89,242,0.2)]"
        >
          {/* Mic button */}
          <div className="w-8 h-8 rounded-full bg-[#7359F2] flex items-center justify-center flex-shrink-0">
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="white"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
              <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
              <line x1="12" x2="12" y1="19" y2="22" />
            </svg>
          </div>
          <span className="text-sm text-white/40 px-1 flex-1">
            Click mic or fn+Space
          </span>
          {/* Image context button — left of history */}
          <button
            type="button"
            data-pill-action="true"
            onClick={() => setImageTrayOpen((open) => !open)}
            onPointerDown={(event) => event.stopPropagation()}
            className={`w-[26px] h-[26px] rounded-full flex items-center justify-center flex-shrink-0 transition-all ${
              imageTrayOpen ? "bg-[#7359F2]/75" : "bg-[#7359F2]/40 hover:bg-[#7359F2]/58"
            }`}
            aria-label="Open recent screenshots"
          >
            <svg
              width="13"
              height="13"
              viewBox="0 0 24 24"
              fill="none"
              stroke="white"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              style={{ opacity: 0.92 }}
            >
              <rect width="18" height="14" x="3" y="5" rx="2" />
              <circle cx="8.5" cy="10.5" r="1.5" />
              <path d="m21 15-5-5L5 21" />
            </svg>
          </button>
          {/* History button */}
          <div className="w-[26px] h-[26px] rounded-full bg-[#7359F2]/40 flex items-center justify-center flex-shrink-0">
            <svg
              width="11"
              height="11"
              viewBox="0 0 24 24"
              fill="none"
              stroke="white"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              style={{ opacity: 0.9 }}
            >
              <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
              <path d="M3 3v5h5" />
              <path d="M12 7v5l4 2" />
            </svg>
          </div>
        </div>
      </div>
    </section>
  );
}
