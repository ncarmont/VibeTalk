"use client";

import { useEffect, useRef, useState } from "react";

const GITHUB_URL = "https://github.com/ncarmont/VibeTalk";
const INSTALL_PROMPT = `Please review the GitHub repo at https://github.com/ncarmont/VibeTalk — it's an open source Mac speech-to-text toolbar. If the code looks safe to you, clone it, build it, and open the app on my Mac:

git clone https://github.com/ncarmont/VibeTalk.git
cd VibeTalk/macos-app
bash build.sh
open build/VibeTalk.app`;

function CopyModal({ onClose }: { onClose: () => void }) {
  const [copied, setCopied] = useState(false);
  const handleCopy = async () => {
    await navigator.clipboard.writeText(INSTALL_PROMPT);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };
  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4" onClick={onClose}>
      <div className="absolute inset-0 bg-black/80 backdrop-blur-md" />
      <div className="relative w-full max-w-lg rounded-2xl border border-[#7359F2]/30 bg-[#111117] p-6 shadow-[0_24px_80px_rgba(0,0,0,0.7)]" onClick={(e) => e.stopPropagation()}>
        <button onClick={onClose} className="absolute right-4 top-4 text-white/30 hover:text-white/70 transition-colors">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6 6 18M6 6l12 12" /></svg>
        </button>
        <div className="flex items-center gap-3 mb-1">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#7359F2]/30 to-[#A78BFA]/20 border border-[#7359F2]/30 flex items-center justify-center text-lg flex-shrink-0">🤖</div>
          <h3 className="text-lg font-bold">Paste into your vibe coding tool</h3>
        </div>
        <p className="text-xs text-white/40 mb-1 ml-12">Paste into Claude Code, Cursor, or any AI coding tool to clone and run VibeTalk locally.</p>
        <p className="text-xs text-white/25 mb-4 ml-12">OSS — review the code before running. No guarantees or liability.</p>
        <div className="rounded-xl bg-[#1c1c28] border border-white/[0.10] p-4 font-mono text-xs text-white/80 whitespace-pre-wrap leading-relaxed mb-4">{INSTALL_PROMPT}</div>
        <div className="flex gap-3">
          <button onClick={handleCopy} className="flex-1 flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-[#7359F2] to-[#6344E0] py-3 font-semibold text-sm transition-all hover:from-[#8B6FF5] hover:to-[#7359F2]">
            {copied ? <><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5" /></svg>Copied!</> : <><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" /><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" /></svg>Copy prompt</>}
          </button>
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium hover:bg-white/10 transition-all">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" /></svg>
            View repo
          </a>
        </div>
      </div>
    </div>
  );
}

function DemoInstallButtons() {
  const [open, setOpen] = useState(false);
  return (
    <>
      {open && <CopyModal onClose={() => setOpen(false)} />}
      <div className="flex flex-wrap items-stretch justify-center gap-3">
        <button onClick={() => setOpen(true)} className="btn-shine inline-flex flex-col items-center gap-1 rounded-full bg-gradient-to-r from-[#7359F2] to-[#6344E0] px-5 py-2.5 text-sm font-semibold transition-all hover:from-[#8B6FF5] hover:to-[#7359F2] shadow-[0_0_24px_rgba(115,89,242,0.3)]">
          <div className="flex items-center gap-2">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" /><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" /></svg>
            Copy into your Vibe Coding tool
          </div>
          <span className="text-xs opacity-60">to download from GitHub</span>
        </button>
        <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="inline-flex items-center justify-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 text-xs font-medium hover:bg-white/10 transition-all">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" /></svg>
          OSS GitHub repo
        </a>
      </div>
    </>
  );
}

type DemoState = "idle" | "listening" | "processing" | "unsupported" | "error";

type BrowserSpeechRecognitionAlternative = {
  transcript: string;
  confidence: number;
};

type BrowserSpeechRecognitionResult = {
  isFinal: boolean;
  length: number;
  [index: number]: BrowserSpeechRecognitionAlternative;
};

type BrowserSpeechRecognitionResultList = {
  length: number;
  [index: number]: BrowserSpeechRecognitionResult;
};

type BrowserSpeechRecognitionEvent = {
  resultIndex: number;
  results: BrowserSpeechRecognitionResultList;
};

type BrowserSpeechRecognitionErrorEvent = {
  error: string;
  message?: string;
};

type BrowserSpeechRecognition = {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  maxAlternatives: number;
  onstart: (() => void) | null;
  onend: (() => void) | null;
  onerror: ((event: BrowserSpeechRecognitionErrorEvent) => void) | null;
  onresult: ((event: BrowserSpeechRecognitionEvent) => void) | null;
  start: () => void;
  stop: () => void;
  abort: () => void;
};

type BrowserSpeechRecognitionConstructor = new () => BrowserSpeechRecognition;

declare global {
  interface Window {
    SpeechRecognition?: BrowserSpeechRecognitionConstructor;
    webkitSpeechRecognition?: BrowserSpeechRecognitionConstructor;
  }
}

const BARS = Array.from({ length: 16 }, (_, index) => index);
const TYPING_BASELINE_WPM = 40;
const TOKENS_PER_WORD = 1.33;
const TYPING_BASELINE_TOKENS_PER_SECOND =
  (TYPING_BASELINE_WPM * TOKENS_PER_WORD) / 60;
const DRAFT_SENTENCE =
  "build me an HTML calculator app that's super nice and modern like this";

// Animation timing constants (must match AnimatedSentence)
const WORD_STEP = 0.45;
const ANIM_START_DELAY = 0.5;
const PAUSE_AT_END = 1.2;
const DRAFT_WORDS = DRAFT_SENTENCE.split(" ");
const TOTAL_PERIOD = ANIM_START_DELAY + DRAFT_WORDS.length * WORD_STEP + PAUSE_AT_END;
// Time from mount when the last word "this" peaks, + a small offset to land on [drag screenshot]
const DRAG_SCREENSHOT_TRIGGER_MS = (ANIM_START_DELAY + (DRAFT_WORDS.length - 1) * WORD_STEP + WORD_STEP * 0.9) * 1000;
const DRAG_SCREENSHOT_DURATION_MS = (PAUSE_AT_END * 0.85) * 1000;

function joinSegments(...parts: string[]) {
  return parts
    .map((part) => part.trim())
    .filter(Boolean)
    .join(" ")
    .trim();
}

function AnimatedSentence({ text, droppedImage, onClearImage }: { text: string; droppedImage: string | null; onClearImage: () => void }) {
  const words = text.split(" ");
  const wordStep = 0.45;
  const startDelay = 0.5;
  const pauseAtEnd = 1.2;
  const totalPeriod = startDelay + words.length * wordStep + pauseAtEnd;

  return (
    <p className="text-xl sm:text-2xl font-semibold leading-snug mb-4" style={{ fontStyle: "italic" }}>
      &ldquo;
      {words.map((word, index) => {
        const peakTime = startDelay + index * wordStep + wordStep / 2;
        const delay = peakTime - totalPeriod / 2;
        return (
          <span key={index}>
            <span
              style={{
                animation: `word-highlight-loop ${totalPeriod.toFixed(2)}s linear infinite`,
                animationDelay: `${delay.toFixed(3)}s`,
                display: "inline",
                fontStyle: "italic",
              }}
            >
              {word}
            </span>
            {" "}
          </span>
        );
      })}
      {droppedImage ? (
        <span style={{ display: "inline-block", verticalAlign: "middle", marginLeft: "0.3em" }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={droppedImage}
            alt="screenshot"
            style={{ height: "2.2em", borderRadius: "0.4em", border: "1.5px solid rgba(167,139,250,0.5)", display: "inline", verticalAlign: "middle", cursor: "pointer" }}
            onClick={onClearImage}
            title="Click to remove"
          />
        </span>
      ) : (
        <span style={{ color: "rgba(167,139,250,0.7)", fontStyle: "italic" }}>[drag screenshot]</span>
      )}
      &rdquo;
    </p>
  );
}

function TerminalInterface({ text }: { text: string }) {
  const [displayedText, setDisplayedText] = useState("");

  useEffect(() => {
    let index = 0;
    const interval = setInterval(() => {
      if (index < text.length) {
        setDisplayedText(text.slice(0, index + 1));
        index++;
      } else {
        clearInterval(interval);
      }
    }, 30);
    return () => clearInterval(interval);
  }, [text]);

  return (
    <div className="w-full max-w-2xl mx-auto mt-6 animate-fade-in">
      <div className="rounded-lg bg-[#0A0A0F] border border-[#7359F2]/30 p-4 sm:p-6 font-mono text-xs sm:text-sm">
        <div className="flex items-start gap-2">
          <span className="text-[#7359F2] flex-shrink-0">$</span>
          <div className="text-white/80 break-all">
            {displayedText}
            {displayedText.length < text.length && (
              <span className="animate-pulse">▌</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function getSpeechSupport() {
  if (typeof window === "undefined") {
    return undefined;
  }

  return window.SpeechRecognition ?? window.webkitSpeechRecognition;
}

function getErrorCopy(error: string) {
  switch (error) {
    case "not-allowed":
    case "service-not-allowed":
      return "Microphone access is blocked in this browser. Allow mic access to run the live demo.";
    case "audio-capture":
      return "No microphone was detected for the browser demo.";
    case "network":
      return "The browser speech engine hit a network error. Try Safari or Chrome on desktop.";
    default:
      return "The browser demo stopped unexpectedly. Click the pill to try again.";
  }
}

function estimateInputTokens(value: string) {
  const clean = value.trim();
  if (!clean) {
    return 0;
  }

  return Math.max(1, Math.ceil(clean.length / 4));
}

function formatRate(rate: number) {
  if (!Number.isFinite(rate) || rate <= 0) {
    return "0.0";
  }

  return rate.toFixed(rate >= 10 ? 0 : 1);
}

function formatDuration(ms: number) {
  if (!Number.isFinite(ms) || ms <= 0) {
    return "0.0s";
  }

  return `${(ms / 1000).toFixed(1)}s`;
}

function PillIconButton({
  label,
  children,
  active = false,
  onClick,
}: {
  label: string;
  children: React.ReactNode;
  active?: boolean;
  onClick?: (event: React.MouseEvent<HTMLButtonElement>) => void;
}) {
  return (
    <button
      type="button"
      data-pill-action="true"
      aria-label={label}
      onClick={onClick}
      onPointerDown={(event) => event.stopPropagation()}
      className={`flex h-[30px] w-[30px] shrink-0 items-center justify-center rounded-full border transition-all ${
        active
          ? "border-white/18 bg-[#7359F2]/75 shadow-[0_0_24px_rgba(115,89,242,0.28)]"
          : "border-transparent bg-[#7359F2]/40 hover:bg-[#7359F2]/58"
      }`}
      title={label}
    >
      {children}
    </button>
  );
}

export default function HeroDemo() {
  const [state, setState] = useState<DemoState>("idle");
  const [liveText, setLiveText] = useState("");
  const [pastedText, setPastedText] = useState("");
  const [errorText, setErrorText] = useState("");
  const [browserSupportsSpeech, setBrowserSupportsSpeech] = useState(true);
  const [hasTriedDemo, setHasTriedDemo] = useState(false);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [endedAt, setEndedAt] = useState<number | null>(null);
  const [now, setNow] = useState(Date.now());
  const [imageTrayOpen, setImageTrayOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [imageButtonHighlighted, setImageButtonHighlighted] = useState(false);
  const [animationKey, setAnimationKey] = useState(0);
  const [droppedImage, setDroppedImage] = useState<string | null>(null);
  const [isDragOver, setIsDragOver] = useState(false);
  const [pillOffset, setPillOffset] = useState({ x: 0, y: 0 });
  const [isPillDragging, setIsPillDragging] = useState(false);

  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const shouldKeepListeningRef = useRef(false);
  const isStoppingRef = useRef(false);
  const hadRecognitionErrorRef = useRef(false);
  const restartTimerRef = useRef<number | null>(null);
  const committedTextRef = useRef("");
  const interimTextRef = useRef("");
  const pillDragStartRef = useRef({ x: 0, y: 0 });
  const pillOffsetStartRef = useRef({ x: 0, y: 0 });

  const finalizeTranscript = () => {
    const finalText = joinSegments(
      committedTextRef.current,
      interimTextRef.current
    );

    committedTextRef.current = finalText;
    interimTextRef.current = "";
    setLiveText(finalText);
    setEndedAt(Date.now());

    if (finalText) {
      setPastedText(finalText);
    }
  };

  const clearRestartTimer = () => {
    if (restartTimerRef.current !== null) {
      window.clearTimeout(restartTimerRef.current);
      restartTimerRef.current = null;
    }
  };

  const stopRecognition = () => {
    shouldKeepListeningRef.current = false;
    isStoppingRef.current = true;
    clearRestartTimer();

    if (!recognitionRef.current) {
      finalizeTranscript();
      setState("idle");
      return;
    }

    setState("processing");

    try {
      recognitionRef.current.stop();
    } catch {
      finalizeTranscript();
      setState("idle");
    }
  };

  const startRecognition = () => {
    const SpeechRecognition = getSpeechSupport();

    if (!SpeechRecognition) {
      setBrowserSupportsSpeech(false);
      setState("unsupported");
      return;
    }

    clearRestartTimer();
    setBrowserSupportsSpeech(true);
    setErrorText("");
    setState("processing");
    setHasTriedDemo(true);
    setStartedAt(Date.now());
    window.setTimeout(() => setAnimationKey((k) => k + 1), 1000);
    setEndedAt(null);
    setNow(Date.now());

    committedTextRef.current = "";
    interimTextRef.current = "";
    setLiveText("");
    setPastedText("");

    shouldKeepListeningRef.current = true;
    isStoppingRef.current = false;
    hadRecognitionErrorRef.current = false;

    if (!recognitionRef.current) {
      const recognition = new SpeechRecognition();
      recognition.lang = "en-US";
      recognition.continuous = true;
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;

      recognition.onstart = () => {
        setState("listening");
      };

      recognition.onresult = (event) => {
        let nextCommitted = committedTextRef.current;
        let nextInterim = "";

        for (let index = event.resultIndex; index < event.results.length; index++) {
          const chunk = event.results[index]?.[0]?.transcript?.trim();
          if (!chunk) {
            continue;
          }

          if (event.results[index].isFinal) {
            nextCommitted = joinSegments(nextCommitted, chunk);
          } else {
            nextInterim = joinSegments(nextInterim, chunk);
          }
        }

        committedTextRef.current = nextCommitted;
        interimTextRef.current = nextInterim;
        setLiveText(joinSegments(nextCommitted, nextInterim));
      };

      recognition.onerror = (event) => {
        if (event.error === "aborted" || event.error === "no-speech") {
          return;
        }

        shouldKeepListeningRef.current = false;
        isStoppingRef.current = false;
        hadRecognitionErrorRef.current = true;
        setErrorText(getErrorCopy(event.error));
        setState("error");
      };

      recognition.onend = () => {
        if (hadRecognitionErrorRef.current) {
          finalizeTranscript();
          isStoppingRef.current = false;
          return;
        }

        if (shouldKeepListeningRef.current) {
          restartTimerRef.current = window.setTimeout(() => {
            restartTimerRef.current = null;
            try {
              recognition.start();
            } catch {
              setErrorText(
                "The browser blocked an automatic restart. Click the pill to keep dictating."
              );
              shouldKeepListeningRef.current = false;
              setState("error");
            }
          }, 140);
          return;
        }

        finalizeTranscript();
        isStoppingRef.current = false;
        setState("idle");
      };

      recognitionRef.current = recognition;
    }

    try {
      recognitionRef.current.start();
    } catch {
      setErrorText(
        "The browser could not start speech recognition. Try clicking the mic again."
      );
      shouldKeepListeningRef.current = false;
      setState("error");
    }
  };

  const toggleRecognition = () => {
    if (state === "listening" || state === "processing") {
      stopRecognition();
      return;
    }

    startRecognition();
  };

  const startPillDrag = (event: React.PointerEvent<HTMLDivElement>) => {
    if ((event.target as HTMLElement).closest("[data-pill-action]")) {
      return;
    }

    setIsPillDragging(true);
    pillDragStartRef.current = { x: event.clientX, y: event.clientY };
    pillOffsetStartRef.current = pillOffset;
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const movePill = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!isPillDragging) {
      return;
    }

    setPillOffset({
      x: pillOffsetStartRef.current.x + event.clientX - pillDragStartRef.current.x,
      y: pillOffsetStartRef.current.y + event.clientY - pillDragStartRef.current.y,
    });
  };

  const stopPillDrag = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!isPillDragging) {
      return;
    }

    setIsPillDragging(false);
    try {
      event.currentTarget.releasePointerCapture(event.pointerId);
    } catch {
      // Pointer capture can already be released by the browser.
    }
  };

  const toggleImageTray = (event: React.MouseEvent<HTMLButtonElement>) => {
    event.stopPropagation();
    setImageTrayOpen((open) => !open);
  };

  const startScreenshotDrag = (event: React.DragEvent<HTMLDivElement>) => {
    event.dataTransfer.setData(
      "text/plain",
      "VibeTalk screenshot context: latest Desktop image"
    );
    event.dataTransfer.effectAllowed = "copy";
  };

  useEffect(() => {
    setBrowserSupportsSpeech(Boolean(getSpeechSupport()));
  }, []);

  useEffect(() => {
    ["/ss-calc-dark.png", "/ss-calc-light.png", "/ss-editor.png"].forEach((src) => {
      const img = new window.Image();
      img.src = src;
    });
  }, []);

  const hasTriedDemoRef = useRef(false);
  useEffect(() => { hasTriedDemoRef.current = hasTriedDemo; }, [hasTriedDemo]);

  // Sync image button highlight with the animated sentence reaching [drag screenshot]
  // Only fires after the user has clicked the mic button
  useEffect(() => {
    const periodMs = TOTAL_PERIOD * 1000;
    let highlightOffTimer: number;

    const runHighlight = () => {
      if (!hasTriedDemoRef.current) return;
      setImageButtonHighlighted(true);
      setImageTrayOpen(true);
      highlightOffTimer = window.setTimeout(() => {
        setImageButtonHighlighted(false);
        setImageTrayOpen(false);
      }, DRAG_SCREENSHOT_DURATION_MS);
    };

    const firstTimer = window.setTimeout(() => {
      runHighlight();
      const interval = window.setInterval(runHighlight, periodMs);
      return () => window.clearInterval(interval);
    }, DRAG_SCREENSHOT_TRIGGER_MS);

    return () => {
      window.clearTimeout(firstTimer);
      window.clearTimeout(highlightOffTimer);
    };
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      const demoSection = document.getElementById('demo-section');
      if (demoSection) {
        demoSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }, 5000);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    if (!startedAt || endedAt) {
      return;
    }

    const timer = window.setInterval(() => setNow(Date.now()), 100);
    return () => window.clearInterval(timer);
  }, [endedAt, startedAt]);

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.repeat || event.code !== "Space") {
        return;
      }

      const pressedFn =
        typeof event.getModifierState === "function" &&
        event.getModifierState("Fn");
      const pressedFallback = event.ctrlKey && event.shiftKey;

      if (!pressedFn && !pressedFallback) {
        return;
      }

      event.preventDefault();
      toggleRecognition();
    }

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [toggleRecognition]);

  useEffect(() => {
    return () => {
      if (restartTimerRef.current !== null) {
        window.clearTimeout(restartTimerRef.current);
        restartTimerRef.current = null;
      }
      shouldKeepListeningRef.current = false;
      isStoppingRef.current = false;
      try {
        recognitionRef.current?.abort();
      } catch {
        // Some browsers throw if abort is called after the recognizer has ended.
      }
    };
  }, []);

  const isListening = state === "listening";
  const isBusy = state === "listening" || state === "processing";
  const measuredText = liveText || pastedText;
  const measuredTokens = estimateInputTokens(measuredText);
  const measurementMs = startedAt
    ? Math.max(0, (endedAt ?? now) - startedAt)
    : 0;
  const speechTokensPerSecond =
    measurementMs > 0 ? measuredTokens / (measurementMs / 1000) : 0;
  const hasSpeechMeasurement = hasTriedDemo && measuredTokens > 0;
  const speedup =
    speechTokensPerSecond > 0
      ? speechTokensPerSecond / TYPING_BASELINE_TOKENS_PER_SECOND
      : 0;
  const hasSpeedupMeasurement = speedup > 0;
  const speedupLabel = hasSpeedupMeasurement ? speedup.toFixed(1) : "1.5-3";
  const pillText = isListening
    ? liveText || "Listening..."
    : state === "processing"
      ? "Warming up..."
      : state === "error" || state === "unsupported"
        ? "Click to retry"
        : browserSupportsSpeech
          ? "Click record or fn+Space"
          : "Open in Safari or Chrome";

  return (
    <section id="demo-section" className="relative z-10 mx-auto max-w-6xl px-4 pt-3 pb-10 text-center sm:px-8 sm:pt-6 sm:pb-14" style={{ animationDelay: '0.45s' }}>
      <div className="mx-auto max-w-5xl">
        <div
          className={`group w-full flex flex-col items-center gap-6 sm:gap-8 rounded-2xl sm:rounded-[1.45rem] border p-6 sm:p-8 text-center shadow-[0_18px_70px_rgba(0,0,0,0.42)] transition-all sm:p-12 animate-hero-in ${
            isDragOver
              ? "border-[#A78BFA]/60 bg-[radial-gradient(circle_at_top_left,_rgba(167,139,250,0.18),_rgba(17,17,23,0.90)_46%,_rgba(10,10,15,0.96)_100%)]"
              : isListening
              ? "border-[#FF5D66]/34 bg-[radial-gradient(circle_at_top_left,_rgba(255,93,102,0.16),_rgba(17,17,23,0.90)_46%,_rgba(10,10,15,0.96)_100%)]"
              : "hover:border-[#7359F2]/35 border-white/[0.08] bg-[radial-gradient(circle_at_top_left,_rgba(115,89,242,0.20),_rgba(17,17,23,0.88)_46%,_rgba(10,10,15,0.96)_100%)]"
          }`}
          onDragOver={(e) => { e.preventDefault(); setIsDragOver(true); }}
          onDragLeave={() => setIsDragOver(false)}
          onDrop={(e) => {
            e.preventDefault();
            setIsDragOver(false);
            const url = e.dataTransfer.getData("text/uri-list") || e.dataTransfer.getData("text/plain");
            if (url) setDroppedImage(url);
          }}
        >
          <div className="w-full max-w-2xl mx-auto animate-fade-in">
            <h2 className="text-xl font-bold tracking-tight text-white sm:text-2xl mb-4">
              See how fast you speak vs type (web demo)
            </h2>
            <p className="text-sm sm:text-base font-semibold italic text-white/40 mb-4">
              <em>Say this out loud after clicking the mic button:</em>
            </p>
            <AnimatedSentence key={animationKey} text={DRAFT_SENTENCE} droppedImage={droppedImage} onClearImage={() => setDroppedImage(null)} />
          </div>

          <div className="relative z-10 flex shrink-0 flex-col items-center w-full">
            <div className="relative flex justify-center w-full">
            <div
              onPointerDown={startPillDrag}
              onPointerMove={movePill}
              onPointerUp={stopPillDrag}
              onPointerCancel={stopPillDrag}
              style={{
                transform: `translate(${pillOffset.x}px, ${pillOffset.y}px)`,
                touchAction: "none",
                userSelect: "none",
                opacity: pastedText && state === "idle" ? 0 : 1,
                transition: "opacity 0.6s ease-in-out, visibility 0.6s ease-in-out",
                visibility: pastedText && state === "idle" ? "hidden" : "visible",
              }}
              className={`relative inline-flex flex-col items-center transition-shadow ${
                isPillDragging ? "cursor-grabbing" : "cursor-grab"
              }`}
            >
                {!hasTriedDemo && (
                  <div className="mb-1 self-start ml-[16px] animate-bounce">
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#A78BFA" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <polyline points="6 9 12 15 18 9"></polyline>
                    </svg>
                  </div>
                )}
                <div className="relative">
                <div className="relative inline-flex items-center gap-2 pl-2 pr-3 py-2 rounded-full bg-[#111117] border border-white/[0.06] shadow-[0_8px_32px_rgba(0,0,0,0.4)] hover:shadow-[0_8px_32px_rgba(115,89,242,0.2)] transition-shadow animate-pill-scale">
                  <button
                    type="button"
                    data-pill-action="true"
                    onClick={toggleRecognition}
                    onPointerDown={(event) => event.stopPropagation()}
                    className={`relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full transition-all ${
                      isListening
                        ? "bg-[#FF5D66] shadow-[0_0_16px_rgba(255,93,102,0.5)]"
                        : "bg-[#7359F2] hover:scale-[1.06] animate-mic-glow"
                    }`}
                    aria-label={isListening ? "Stop recording" : "Start recording"}
                  >
                    {isListening ? (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" className="text-white">
                        <rect x="7" y="7" width="10" height="10" rx="2" />
                      </svg>
                    ) : (
                      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                        <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                        <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                        <line x1="12" x2="12" y1="19" y2="22" />
                      </svg>
                    )}
                  </button>

                  <span className="text-sm text-white/40 px-1 overflow-hidden" style={{ width: 180, minWidth: 180, whiteSpace: "nowrap", direction: "rtl", textOverflow: "ellipsis" }}>
                    <span style={{ direction: "ltr", unicodeBidi: "bidi-override" }}>{pillText}</span>
                  </span>

                  {/* Screenshots button */}
                  <div className="relative">
                    <button
                      type="button"
                      data-pill-action="true"
                      onClick={toggleImageTray}
                      onPointerDown={(e) => e.stopPropagation()}
                      aria-label="Open recent screenshots"
                      className={`w-[26px] h-[26px] rounded-full flex items-center justify-center flex-shrink-0 transition-all ${
                        imageTrayOpen ? "bg-[#7359F2]/75" : "bg-[#7359F2]/40 hover:bg-[#7359F2]/60"
                      } ${imageButtonHighlighted ? "animate-mic-glow scale-110" : ""}`}
                    >
                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.92 }}>
                        <rect width="18" height="14" x="3" y="5" rx="2" />
                        <circle cx="8.5" cy="10.5" r="1.5" />
                        <path d="m21 15-5-5L5 21" />
                      </svg>
                    </button>
                    {imageTrayOpen && (
                      <div className="absolute bottom-full right-0 mb-3 z-30 w-[300px] rounded-2xl border border-[#7359F2]/24 bg-[#111117]/98 p-3 text-left shadow-[0_-8px_40px_rgba(0,0,0,0.6)] backdrop-blur-xl">
                        <div className="mb-2 flex items-center justify-between gap-3">
                          <p className="text-[10px] font-bold uppercase tracking-[0.22em] text-[#B7A6FF]">Recent screenshots</p>
                          <span className="rounded-full bg-emerald-400/12 px-2 py-0.5 text-[10px] font-semibold text-emerald-200">latest ready</span>
                        </div>
                        <div className="grid grid-cols-3 gap-2">
                          {[
                            { src: "/ss-calc-dark.png", label: "latest", time: "just now" },
                            { src: "/ss-calc-light.png", label: null, time: "2m ago" },
                            { src: "/ss-editor.png", label: null, time: "5m ago" },
                          ].map((item, index) => (
                            <div
                              key={index}
                              draggable
                              onDragStart={(e) => {
                                e.dataTransfer.setData("text/uri-list", window.location.origin + item.src);
                                e.dataTransfer.setData("text/plain", window.location.origin + item.src);
                                e.dataTransfer.effectAllowed = "copy";
                              }}
                              className={`relative h-16 cursor-grab overflow-hidden rounded-xl border ${
                                index === 0 ? "border-[#A78BFA]/70 shadow-[0_0_18px_rgba(115,89,242,0.28)]" : "border-white/10"
                              }`}
                              title="Drag this screenshot into a chat"
                            >
                              {/* eslint-disable-next-line @next/next/no-img-element */}
                              <img src={item.src} alt="" className="w-full h-full object-cover pointer-events-none" draggable={false} />
                              {item.label && (
                                <span className="absolute left-1.5 top-1.5 rounded-full bg-[#7359F2] px-1.5 py-0.5 text-[9px] font-bold text-white">{item.label}</span>
                              )}
                              <span className="absolute bottom-1 right-1.5 text-[8px] text-white/70 bg-black/40 rounded px-1">{item.time}</span>
                            </div>
                          ))}
                        </div>
                        <p className="mt-2 text-xs leading-relaxed text-white/42">
                          In the Mac app, drag any screenshot directly into Claude, Cursor, or any AI chat.
                        </p>
                        <div className="absolute -bottom-1.5 right-3 h-3 w-3 rotate-45 border-b border-r border-[#7359F2]/24 bg-[#111117]" />
                      </div>
                    )}
                  </div>

                  {/* History button */}
                  <div className="relative">
                    <button
                      type="button"
                      data-pill-action="true"
                      onClick={(e) => { e.stopPropagation(); setHistoryOpen((o) => !o); }}
                      onPointerDown={(e) => e.stopPropagation()}
                      aria-label="Recent transcripts"
                      className={`w-[26px] h-[26px] rounded-full flex items-center justify-center flex-shrink-0 transition-all ${
                        historyOpen ? "bg-[#7359F2]/75" : "bg-[#7359F2]/40 hover:bg-[#7359F2]/60"
                      }`}
                    >
                      <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.9 }}>
                        <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
                        <path d="M3 3v5h5" />
                        <path d="M12 7v5l4 2" />
                      </svg>
                    </button>
                    {historyOpen && (
                      <div className="absolute bottom-full right-0 mb-3 z-30 w-[240px] rounded-2xl border border-[#7359F2]/24 bg-[#111117]/98 p-3 text-left shadow-[0_-8px_40px_rgba(0,0,0,0.6)] backdrop-blur-xl">
                        <span className="mb-2 block text-[10px] font-bold uppercase tracking-[0.22em] text-[#B7A6FF]">Recent Transcripts</span>
                        <div className="flex flex-col gap-1.5">
                          {[
                            { text: "build me an HTML calculator app that's super nice and modern", time: "just now", tokens: "18 tok" },
                            { text: "refactor this to use react query instead of useEffect", time: "4m ago", tokens: "12 tok" },
                            { text: "add dark mode and animate the toggle button", time: "11m ago", tokens: "10 tok" },
                          ].map((item, i) => (
                            <div key={i} className={`rounded-lg px-2 py-1.5 ${i === 0 ? "bg-[#7359F2]/15 border border-[#7359F2]/25" : "bg-white/[0.03]"}`}>
                              <p className="text-[10px] leading-relaxed text-white/70 line-clamp-2">&ldquo;{item.text}&rdquo;</p>
                              <div className="mt-1 flex items-center gap-2">
                                <span className="text-[9px] text-white/30">{item.time}</span>
                                <span className="text-[9px] text-[#A78BFA]/60">{item.tokens}</span>
                              </div>
                            </div>
                          ))}
                        </div>
                        <div className="absolute -bottom-1.5 right-3 h-3 w-3 rotate-45 border-b border-r border-[#7359F2]/24 bg-[#111117]" />
                      </div>
                    )}
                  </div>
                </div>
                {/* This is what it actually looks like — absolute below just the pill bar */}
                <div className="absolute top-full mt-2 right-0 hidden flex-col items-end gap-1 text-[#B7A6FF]/70 sm:flex">
                  <svg width="44" height="28" viewBox="0 0 44 28" fill="none" className="mr-10">
                    <path d="M4 24 C12 24 28 10 40 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
                    <path d="M32 4 L40 6 L38 14" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                  <span className="text-xs font-semibold text-white/48 max-w-[180px] leading-tight text-right">This is what it looks like at the bottom of your screen</span>
                </div>
                </div>

                {/* try this demo arrow — points at mic normally, shifts right to image button when highlighted */}
                <div
                  className="mt-2 self-start flex flex-col items-center gap-0.5 text-white/30 animate-scroll-bounce transition-all duration-500"
                  style={{ width: 32, transform: imageButtonHighlighted ? "translateX(118px)" : "translateX(0)" }}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" style={{ transform: "scaleY(-1)" }}>
                    <path d="M6 9l6 6 6-6" />
                  </svg>
                  <span className="text-[9px] font-semibold uppercase tracking-widest whitespace-nowrap text-center block">
                    {imageButtonHighlighted ? "drag a screenshot!" : "try this demo"}
                  </span>
                </div>

            </div>
            </div>

            {pastedText && state === "idle" && (
              <TerminalInterface text={pastedText} />
            )}

          </div>

          <div className="w-full border-t border-white/[0.08] pt-6 sm:pt-8">
            <div className="mx-auto max-w-3xl text-center">
              <p className="text-[10px] sm:text-[11px] font-bold uppercase tracking-[0.24em] text-[#B7A6FF]">
                {hasSpeechMeasurement ? "Read out the sentence above" : "Typical speedup"}
              </p>
              <p className="mt-4 text-5xl sm:text-6xl font-bold tracking-tight text-white">
                <span className="text-[#7359F2]">{speedupLabel}x</span>
                <span className="ml-3 text-2xl sm:text-3xl font-semibold text-white/40">speedup</span>
              </p>
              <p className="mt-4 text-xs sm:text-sm text-white/50 leading-relaxed">
                {hasSpeechMeasurement
                  ? `${formatRate(speechTokensPerSecond)} tok/s spoken input vs ${formatRate(
                      TYPING_BASELINE_TOKENS_PER_SECOND
                    )} tok/s typical typing.`
                  : "and see your speed up versus typing"}
              </p>
              {pastedText && (
                <p className="mx-auto mt-4 line-clamp-2 max-w-2xl text-xs sm:text-sm leading-relaxed text-white/40 italic">
                  &ldquo;{pastedText}&rdquo;
                </p>
              )}
            </div>
          </div>

        </div>

        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <DemoInstallButtons />
        </div>

        {(state === "error" || state === "unsupported") && (
          <p className="mt-4 text-sm leading-relaxed text-[#FFE7A2]">
            {errorText ||
              "This browser does not expose live speech recognition for the demo. Try Safari or Chrome on desktop."}
          </p>
        )}
      </div>
    </section>
  );
}
