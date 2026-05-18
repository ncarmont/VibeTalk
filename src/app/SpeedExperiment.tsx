"use client";

import { useEffect, useMemo, useRef, useState } from "react";

type RunState = "idle" | "running" | "done";
type SpeechState = RunState | "unsupported" | "error";

type SpeechAlternative = {
  transcript: string;
  confidence: number;
};

type SpeechResult = {
  isFinal: boolean;
  length: number;
  [index: number]: SpeechAlternative;
};

type SpeechResultList = {
  length: number;
  [index: number]: SpeechResult;
};

type SpeechEvent = {
  resultIndex: number;
  results: SpeechResultList;
};

type SpeechErrorEvent = {
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
  onerror: ((event: SpeechErrorEvent) => void) | null;
  onresult: ((event: SpeechEvent) => void) | null;
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

const PROMPTS = [
  "Most work gets faster when your first draft can move at the speed of your voice.",
  "When ideas are already clear, speaking them out loud beats waiting for your fingers.",
  "The fastest way to capture a thought is to say it while it is still fresh.",
];

function getSpeechSupport() {
  if (typeof window === "undefined") {
    return undefined;
  }

  return window.SpeechRecognition ?? window.webkitSpeechRecognition;
}

function joinSegments(...parts: string[]) {
  return parts
    .map((part) => part.trim())
    .filter(Boolean)
    .join(" ")
    .trim();
}

function normalizeText(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function estimateInputTokens(value: string) {
  const clean = value.trim();
  if (!clean) {
    return 0;
  }

  return Math.max(1, Math.ceil(clean.length / 4));
}

function getMatchPercent(value: string, target: string) {
  const written = normalizeText(value);
  const expected = normalizeText(target);

  if (!written || !expected) {
    return 0;
  }

  const writtenWords = written.split(/\s+/);
  const expectedWords = expected.split(/\s+/);
  const matchedWords = writtenWords.reduce((count, word, index) => {
    return count + (word === expectedWords[index] ? 1 : 0);
  }, 0);

  return Math.round((matchedWords / expectedWords.length) * 100);
}

function elapsedMs(startedAt: number | null, endedAt: number | null, now: number) {
  if (!startedAt) {
    return 0;
  }

  return Math.max(0, (endedAt ?? now) - startedAt);
}

function rateFor(text: string, durationMs: number) {
  if (durationMs <= 0) {
    return 0;
  }

  return estimateInputTokens(text) / (durationMs / 1000);
}

function formatTime(durationMs: number) {
  if (durationMs <= 0) {
    return "0.0s";
  }

  return `${(durationMs / 1000).toFixed(1)}s`;
}

function formatRate(rate: number) {
  if (!Number.isFinite(rate) || rate <= 0) {
    return "0.0";
  }

  return rate.toFixed(rate >= 10 ? 0 : 1);
}

function getSpeechErrorCopy(error: string) {
  switch (error) {
    case "not-allowed":
    case "service-not-allowed":
      return "Mic access is blocked for this browser.";
    case "audio-capture":
      return "No browser microphone was detected.";
    case "network":
      return "The browser speech engine hit a network error.";
    default:
      return "Speech capture stopped unexpectedly.";
  }
}

function Metric({
  label,
  value,
  detail,
}: {
  label: string;
  value: string;
  detail: string;
}) {
  return (
    <div className="min-w-0 rounded-2xl border border-white/[0.07] bg-white/[0.035] px-4 py-3">
      <p className="text-[10px] font-semibold uppercase tracking-[0.22em] text-white/28">
        {label}
      </p>
      <p className="mt-1 text-2xl font-bold text-white">{value}</p>
      <p className="mt-1 text-xs text-white/34">{detail}</p>
    </div>
  );
}

function StatusPill({
  state,
  children,
}: {
  state: "idle" | "running" | "done" | "error";
  children: React.ReactNode;
}) {
  const className =
    state === "running"
      ? "border-[#7359F2]/35 bg-[#7359F2]/18 text-[#C7B9FF]"
      : state === "done"
        ? "border-emerald-400/25 bg-emerald-400/10 text-emerald-200"
        : state === "error"
          ? "border-red-400/25 bg-red-400/10 text-red-200"
          : "border-white/10 bg-white/[0.04] text-white/40";

  return (
    <span className={`rounded-full border px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.18em] ${className}`}>
      {children}
    </span>
  );
}

export default function SpeedExperiment() {
  const [promptIndex, setPromptIndex] = useState(0);
  const [gameStarted, setGameStarted] = useState(false);
  const [typedText, setTypedText] = useState("");
  const [speechText, setSpeechText] = useState("");
  const [typingState, setTypingState] = useState<RunState>("idle");
  const [speechState, setSpeechState] = useState<SpeechState>("idle");
  const [typingStartedAt, setTypingStartedAt] = useState<number | null>(null);
  const [typingEndedAt, setTypingEndedAt] = useState<number | null>(null);
  const [speechStartedAt, setSpeechStartedAt] = useState<number | null>(null);
  const [speechEndedAt, setSpeechEndedAt] = useState<number | null>(null);
  const [speechError, setSpeechError] = useState("");
  const [now, setNow] = useState(Date.now());
  const [browserSupportsSpeech, setBrowserSupportsSpeech] = useState(true);

  const typingInputRef = useRef<HTMLTextAreaElement | null>(null);
  const recognitionRef = useRef<BrowserSpeechRecognition | null>(null);
  const speechRunningRef = useRef(false);
  const committedSpeechRef = useRef("");
  const interimSpeechRef = useRef("");

  const prompt = PROMPTS[promptIndex];

  const typingDuration = elapsedMs(typingStartedAt, typingEndedAt, now);
  const speechDuration = elapsedMs(speechStartedAt, speechEndedAt, now);
  const typedTokens = estimateInputTokens(typedText);
  const speechTokens = estimateInputTokens(speechText);
  const typingRate = rateFor(typedText, typingDuration);
  const speechRate = rateFor(speechText, speechDuration);
  const typingMatch = getMatchPercent(typedText, prompt);
  const speechMatch = getMatchPercent(speechText, prompt);

  const speedSummary = useMemo(() => {
    if (!typingRate || !speechRate) {
      return {
        label: "Run both lanes",
        detail: "Your speed-up appears here",
        value: "0.0x",
      };
    }

    if (speechRate >= typingRate) {
      return {
        label: "Speech speed-up",
        detail: "Speaking versus typing",
        value: `${(speechRate / typingRate).toFixed(1)}x`,
      };
    }

    return {
      label: "Typing edge",
      detail: "Typing versus speaking",
      value: `${(typingRate / speechRate).toFixed(1)}x`,
    };
  }, [speechRate, typingRate]);

  const startGame = (focusTyping = true) => {
    try {
      recognitionRef.current?.abort();
    } catch {
      // The browser recognizer can throw if it is already stopped.
    }

    speechRunningRef.current = false;
    committedSpeechRef.current = "";
    interimSpeechRef.current = "";

    setGameStarted(true);
    setTypedText("");
    setSpeechText("");
    setTypingState("idle");
    setSpeechState("idle");
    setTypingStartedAt(null);
    setTypingEndedAt(null);
    setSpeechStartedAt(null);
    setSpeechEndedAt(null);
    setSpeechError("");

    if (focusTyping) {
      window.setTimeout(() => typingInputRef.current?.focus(), 60);
    }
  };

  const rotatePrompt = () => {
    setPromptIndex((index) => (index + 1) % PROMPTS.length);
    setGameStarted(false);
    setTypedText("");
    setSpeechText("");
    setTypingState("idle");
    setSpeechState("idle");
    setTypingStartedAt(null);
    setTypingEndedAt(null);
    setSpeechStartedAt(null);
    setSpeechEndedAt(null);
    setSpeechError("");
  };

  const finishTyping = () => {
    if (typingState === "running") {
      setTypingEndedAt(Date.now());
      setTypingState("done");
    }
  };

  const handleTypingChange = (value: string) => {
    setTypedText(value);

    if (!gameStarted || typingState === "done") {
      return;
    }

    if (value.trim() && !typingStartedAt) {
      setTypingStartedAt(Date.now());
      setTypingState("running");
    }

    if (normalizeText(value) === normalizeText(prompt)) {
      setTypingEndedAt(Date.now());
      setTypingState("done");
    }
  };

  const finishSpeech = () => {
    if (!speechRunningRef.current) {
      return;
    }

    speechRunningRef.current = false;
    setSpeechEndedAt(Date.now());
    setSpeechState("done");

    try {
      recognitionRef.current?.stop();
    } catch {
      // Stop can throw if the recognition session has already ended.
    }
  };

  const startSpeech = () => {
    if (!gameStarted) {
      startGame(false);
    }

    const SpeechRecognition = getSpeechSupport();

    if (!SpeechRecognition) {
      setBrowserSupportsSpeech(false);
      setSpeechState("unsupported");
      setSpeechError("Open this in Safari or Chrome to run the speaking lane.");
      return;
    }

    try {
      recognitionRef.current?.abort();
    } catch {
      // Ignore stale browser recognizer state.
    }

    const recognition = new SpeechRecognition();
    recognition.lang = "en-US";
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.maxAlternatives = 1;

    committedSpeechRef.current = "";
    interimSpeechRef.current = "";
    speechRunningRef.current = true;
    setBrowserSupportsSpeech(true);
    setSpeechText("");
    setSpeechError("");
    setSpeechStartedAt(Date.now());
    setSpeechEndedAt(null);
    setSpeechState("running");

    recognition.onstart = () => {
      if (!speechRunningRef.current) {
        return;
      }

      setSpeechStartedAt(Date.now());
      setSpeechState("running");
    };

    recognition.onresult = (event) => {
      let nextCommitted = committedSpeechRef.current;
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

      committedSpeechRef.current = nextCommitted;
      interimSpeechRef.current = nextInterim;
      setSpeechText(joinSegments(nextCommitted, nextInterim));
    };

    recognition.onerror = (event) => {
      if (event.error === "aborted" || event.error === "no-speech") {
        return;
      }

      speechRunningRef.current = false;
      setSpeechEndedAt(Date.now());
      setSpeechState("error");
      setSpeechError(getSpeechErrorCopy(event.error));
    };

    recognition.onend = () => {
      if (!speechRunningRef.current) {
        return;
      }

      speechRunningRef.current = false;
      setSpeechEndedAt(Date.now());
      setSpeechState("done");
      setSpeechText(joinSegments(committedSpeechRef.current, interimSpeechRef.current));
    };

    recognitionRef.current = recognition;

    try {
      recognition.start();
    } catch {
      speechRunningRef.current = false;
      setSpeechEndedAt(Date.now());
      setSpeechState("error");
      setSpeechError("The browser could not start the microphone.");
    }
  };

  useEffect(() => {
    setBrowserSupportsSpeech(Boolean(getSpeechSupport()));
  }, []);

  useEffect(() => {
    if (typingState !== "running" && speechState !== "running") {
      return;
    }

    const timer = window.setInterval(() => setNow(Date.now()), 100);
    return () => window.clearInterval(timer);
  }, [speechState, typingState]);

  useEffect(() => {
    return () => {
      speechRunningRef.current = false;
      try {
        recognitionRef.current?.abort();
      } catch {
        // Browser speech cleanup is best-effort.
      }
    };
  }, []);

  return (
    <section className="relative z-10 px-6 sm:px-8 py-16 sm:py-24 max-w-6xl mx-auto">
      <div className="mb-8 text-center">
        <div className="inline-flex items-center gap-2 rounded-full border border-[#7359F2]/25 bg-[#7359F2]/10 px-4 py-1.5 text-sm text-[#B7A6FF]">
          <span className="h-2 w-2 rounded-full bg-[#A78BFA]" />
          Speed experiment
        </div>
        <h2 className="mt-5 text-2xl sm:text-3xl md:text-4xl font-bold">
          Put it to the test
        </h2>
        <p className="mx-auto mt-3 max-w-2xl text-sm sm:text-base leading-relaxed text-white/38">
          Type the prompt once, say it once, then compare estimated input tokens per second.
        </p>
        <p className="mx-auto mt-4 max-w-2xl text-lg sm:text-xl font-semibold leading-relaxed text-white/78">
          Vibe coding was the first wave. The next one is vibe talking.
        </p>
      </div>

      <div className="relative overflow-hidden rounded-[2rem] border border-white/10 bg-[#101119]/90 shadow-[0_30px_120px_rgba(5,5,12,0.65)]">
        <div className="absolute inset-x-0 top-0 h-28 bg-[radial-gradient(circle_at_top,_rgba(115,89,242,0.28),_transparent_62%)] pointer-events-none" />

        <div className="relative p-4 sm:p-6 lg:p-8">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-stretch lg:justify-between">
            <div className="flex-1 rounded-2xl border border-white/[0.07] bg-black/18 p-4 sm:p-5">
              <p className="text-[10px] font-semibold uppercase tracking-[0.24em] text-white/28">
                Test prompt
              </p>
              <p className="mt-3 text-lg sm:text-xl font-semibold leading-relaxed text-white/88">
                {prompt}
              </p>
            </div>

            <div className="flex flex-col gap-3 sm:min-w-[210px]">
              <button
                type="button"
                onClick={() => startGame()}
                className="btn-shine rounded-2xl bg-gradient-to-r from-[#7359F2] to-[#6344E0] px-5 py-4 text-sm font-bold text-white shadow-[0_0_45px_rgba(115,89,242,0.28)] transition-all hover:from-[#8B6FF5] hover:to-[#7359F2]"
              >
                Start the game
              </button>
              <button
                type="button"
                onClick={rotatePrompt}
                className="rounded-2xl border border-white/10 bg-white/[0.04] px-5 py-3 text-sm font-semibold text-white/58 transition-all hover:border-white/20 hover:bg-white/[0.07]"
              >
                New prompt
              </button>
            </div>
          </div>

          <div className="mt-5 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Metric
              label="Typing"
              value={`${formatRate(typingRate)} tok/s`}
              detail={`${typedTokens} tokens in ${formatTime(typingDuration)}`}
            />
            <Metric
              label="Speaking"
              value={`${formatRate(speechRate)} tok/s`}
              detail={`${speechTokens} tokens in ${formatTime(speechDuration)}`}
            />
            <Metric
              label={speedSummary.label}
              value={speedSummary.value}
              detail={speedSummary.detail}
            />
            <Metric
              label="Prompt size"
              value={`${estimateInputTokens(prompt)} tok`}
              detail="Same estimator for both"
            />
          </div>

          <div className="mt-5 grid gap-5 lg:grid-cols-2">
            <div className="rounded-[1.5rem] border border-white/[0.07] bg-[#0A0C12]/82 p-4 sm:p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-[0.24em] text-white/30">
                    Typing box
                  </p>
                  <h3 className="mt-1 text-xl font-semibold">Type it fast</h3>
                </div>
                <StatusPill state={typingState}>{typingState}</StatusPill>
              </div>

              <textarea
                ref={typingInputRef}
                value={typedText}
                onChange={(event) => handleTypingChange(event.target.value)}
                disabled={!gameStarted}
                spellCheck={false}
                placeholder="Start the game, then type the prompt here."
                className="mt-4 min-h-[180px] w-full resize-none rounded-2xl border border-white/[0.08] bg-white/[0.035] p-4 text-base leading-7 text-white outline-none transition-all placeholder:text-white/22 focus:border-[#7359F2]/45 focus:bg-white/[0.055] disabled:cursor-not-allowed disabled:opacity-55"
              />

              <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
                <div className="flex gap-2 text-xs text-white/32">
                  <span>{formatTime(typingDuration)}</span>
                  <span>{typingMatch}% match</span>
                  <span>{typedTokens} tokens</span>
                </div>
                <button
                  type="button"
                  onClick={finishTyping}
                  disabled={typingState !== "running"}
                  className="rounded-xl border border-white/10 bg-white/[0.05] px-4 py-2 text-sm font-semibold text-white/62 transition-all hover:border-white/20 hover:bg-white/[0.08] disabled:cursor-not-allowed disabled:opacity-35"
                >
                  Finish typing
                </button>
              </div>
            </div>

            <div className="rounded-[1.5rem] border border-white/[0.07] bg-[#0A0C12]/82 p-4 sm:p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-[11px] font-semibold uppercase tracking-[0.24em] text-white/30">
                    Speaking box
                  </p>
                  <h3 className="mt-1 text-xl font-semibold">Say it out loud</h3>
                </div>
                <StatusPill
                  state={
                    speechState === "error" || speechState === "unsupported"
                      ? "error"
                      : speechState
                  }
                >
                  {speechState === "unsupported" ? "no mic" : speechState}
                </StatusPill>
              </div>

              <textarea
                value={speechText}
                readOnly
                placeholder={
                  browserSupportsSpeech
                    ? "Start speaking, then stop when you finish the prompt."
                    : "Safari or Chrome is needed for browser speech capture."
                }
                className="mt-4 min-h-[180px] w-full resize-none rounded-2xl border border-white/[0.08] bg-white/[0.035] p-4 text-base leading-7 text-white outline-none placeholder:text-white/22"
              />

              <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
                <div className="flex gap-2 text-xs text-white/32">
                  <span>{formatTime(speechDuration)}</span>
                  <span>{speechMatch}% match</span>
                  <span>{speechTokens} tokens</span>
                </div>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={startSpeech}
                    disabled={speechState === "running"}
                    className="rounded-xl border border-[#7359F2]/30 bg-[#7359F2]/18 px-4 py-2 text-sm font-semibold text-[#C7B9FF] transition-all hover:border-[#A78BFA]/45 hover:bg-[#7359F2]/25 disabled:cursor-not-allowed disabled:opacity-35"
                  >
                    Start speaking
                  </button>
                  <button
                    type="button"
                    onClick={finishSpeech}
                    disabled={speechState !== "running"}
                    className="rounded-xl border border-white/10 bg-white/[0.05] px-4 py-2 text-sm font-semibold text-white/62 transition-all hover:border-white/20 hover:bg-white/[0.08] disabled:cursor-not-allowed disabled:opacity-35"
                  >
                    Stop
                  </button>
                </div>
              </div>

              {speechError ? (
                <p className="mt-3 rounded-xl border border-red-400/15 bg-red-400/8 px-3 py-2 text-xs text-red-100/72">
                  {speechError}
                </p>
              ) : null}
            </div>
          </div>

          <p className="mt-5 text-center text-xs leading-relaxed text-white/24">
            Token counts are estimated consistently from text length, so the speed-up is most useful as a personal side-by-side comparison.
          </p>
        </div>
      </div>
    </section>
  );
}
