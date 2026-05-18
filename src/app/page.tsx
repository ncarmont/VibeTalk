"use client";

import { useState, useRef } from "react";
import AnimatedBackground from "./AnimatedBackground";
import ScrollReveal from "./ScrollReveal";
import DraggablePill from "./DraggablePill";
import HeroText from "./HeroText";
import HeroDemo from "./HeroDemo";

const GITHUB_URL = "https://github.com/ncarmont/VibeTalk";
const INSTALL_PROMPT = `Please review the GitHub repo at https://github.com/ncarmont/VibeTalk — it's an open source Mac speech-to-text toolbar. If the code looks safe to you, clone it, build it, and open the app on my Mac:

git clone https://github.com/ncarmont/VibeTalk.git
cd VibeTalk/macos-app
bash build.sh
open build/VibeTalk.app`;

function CopyPromptModal({ onClose }: { onClose: () => void }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    await navigator.clipboard.writeText(INSTALL_PROMPT);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4" onClick={onClose}>
      <div className="absolute inset-0 bg-black/80 backdrop-blur-md" />
      <div
        className="relative w-full max-w-lg rounded-2xl border border-[#7359F2]/30 bg-[#111117] p-6 shadow-[0_24px_80px_rgba(0,0,0,0.8)]"
        onClick={(e) => e.stopPropagation()}
      >
        <button onClick={onClose} className="absolute right-4 top-4 text-white/30 hover:text-white/70 transition-colors">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M18 6 6 18M6 6l12 12" />
          </svg>
        </button>
        <div className="flex items-center gap-3 mb-1">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#7359F2]/30 to-[#A78BFA]/20 border border-[#7359F2]/30 flex items-center justify-center text-lg flex-shrink-0">🤖</div>
          <h3 className="text-lg font-bold">Paste into your vibe coding tool</h3>
        </div>
        <p className="text-xs text-white/40 mb-1 ml-12">Paste into Claude Code, Cursor, or any AI coding tool to clone and run VibeTalk locally.</p>
        <p className="text-xs text-white/25 mb-4 ml-12">OSS — review the code before running. No guarantees or liability.</p>
        <div className="rounded-xl bg-[#1c1c28] border border-white/[0.10] p-4 font-mono text-xs text-white/80 whitespace-pre-wrap leading-relaxed mb-4">
          {INSTALL_PROMPT}
        </div>
        <div className="flex gap-3">
          <button
            onClick={handleCopy}
            className="flex-1 flex items-center justify-center gap-2 rounded-xl bg-gradient-to-r from-[#7359F2] to-[#6344E0] py-3 font-semibold text-sm transition-all hover:from-[#8B6FF5] hover:to-[#7359F2]"
          >
            {copied ? (
              <>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6 9 17l-5-5" /></svg>
                Copied!
              </>
            ) : (
              <>
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" /><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" /></svg>
                Copy prompt
              </>
            )}
          </button>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-4 py-3 text-sm font-medium hover:bg-white/10 transition-all"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" /></svg>
            View repo
          </a>
        </div>
      </div>
    </div>
  );
}

function InstallButtons({ size = "sm", onOpenModal }: { size?: "sm" | "lg"; onOpenModal: () => void }) {
  return (
    <>
      <div className={`flex flex-wrap items-stretch justify-center gap-3 ${size === "lg" ? "gap-4" : ""}`}>
        <button
          onClick={onOpenModal}
          className={`btn-shine inline-flex flex-col items-center gap-1 rounded-${size === "lg" ? "3xl" : "full"} bg-gradient-to-r from-[#7359F2] to-[#6344E0] font-semibold transition-all hover:from-[#8B6FF5] hover:to-[#7359F2] animate-download-glow shadow-[0_0_30px_rgba(115,89,242,0.3)] ${
            size === "lg" ? "px-10 py-4 text-lg" : "px-6 py-2.5 text-sm"
          }`}
        >
          <div className="flex items-center gap-2">
            <svg width={size === "lg" ? "20" : "15"} height={size === "lg" ? "20" : "15"} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" /><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2" /></svg>
            Copy into your Vibe Coding tool
          </div>
          <span className={`opacity-60 ${size === "lg" ? "text-sm" : "text-xs"}`}>to download from GitHub</span>
        </button>
        <a
          href={GITHUB_URL}
          target="_blank"
          rel="noopener noreferrer"
          className={`inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 font-medium hover:bg-white/10 hover:border-white/20 transition-all self-stretch justify-center ${
            size === "lg" ? "px-6 text-base" : "px-4 text-xs"
          }`}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" /></svg>
          OSS GitHub repo
        </a>
      </div>
    </>
  );
}

export default function Home() {
  const [modalOpen, setModalOpen] = useState(false);

  return (
    <main className="min-h-screen bg-[#0A0A0F] text-white overflow-hidden noise-overlay">
      {modalOpen && <CopyPromptModal onClose={() => setModalOpen(false)} />}
      <AnimatedBackground />

      {/* Nav */}
      <nav className="relative z-10 flex items-center justify-between px-5 py-3.5 sm:px-8 sm:py-4 max-w-6xl mx-auto">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#7359F2] to-[#A78BFA] flex items-center justify-center shadow-[0_0_20px_rgba(115,89,242,0.4)]">
            <svg
              width="18"
              height="18"
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
          <span className="text-lg font-bold tracking-tight">VibeTalk</span>
        </div>
        <a
          href={GITHUB_URL}
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-xs sm:text-sm font-medium"
        >
          <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" /></svg>
          GitHub
        </a>
      </nav>

      {/* Hero */}
      <section className="snap-section relative z-10 text-center px-4 pt-6 pb-4 sm:px-8 sm:pt-10 sm:pb-6 max-w-4xl mx-auto">
        <div className="mb-3 inline-flex items-center gap-2 rounded-full border border-[#7359F2]/30 bg-[#7359F2]/10 px-3 py-1 text-xs text-[#A78BFA] sm:mb-4 sm:text-sm animate-hero-in" style={{ animationDelay: '0s' }}>
          <span className="w-2 h-2 rounded-full bg-green-400 animate-pulse" />
          Open-source free Mac dictation
        </div>

        <HeroText />

        {/* Primary CTA */}
        <div className="mt-4 sm:mt-5 animate-hero-in flex flex-col items-center gap-3" style={{ animationDelay: '0.15s' }}>
          <p className="text-sm sm:text-base text-white/60 font-medium">
            A vibe coding toolbar for Mac to input prompts <span className="text-[#A78BFA] font-semibold">~1.5–3x faster</span>.
          </p>
          <InstallButtons size="sm" onOpenModal={() => setModalOpen(true)} />
        </div>


        {/* Icons Section */}
        <p className="mt-8 text-[11px] font-bold uppercase tracking-widest text-white/35 text-center">3 main features</p>
        <div className="mt-3 flex justify-center gap-6 sm:gap-8 px-4 animate-hero-in" style={{ animationDelay: '0.35s' }}>
          <div className="flex flex-col items-center gap-2 max-w-[140px]">
            <div className="text-2xl sm:text-3xl">🎤</div>
            <p className="text-xs sm:text-sm font-medium text-white/60 text-center leading-snug">Talk prompts out loud (STT)<br /><span className="text-xs text-white/30 font-normal">(to input 1.5–3x faster)</span></p>
          </div>
          <div className="flex flex-col items-center gap-2 max-w-[140px]">
            <div className="text-2xl sm:text-3xl">🖼️</div>
            <p className="text-xs sm:text-sm font-medium text-white/60 text-center leading-snug">Drag &amp; drop screenshots<br /><span className="text-xs text-white/30 font-normal">(an image says 1000 words)</span></p>
          </div>
          <div className="flex flex-col items-center gap-2 max-w-[140px]">
            <div className="text-2xl sm:text-3xl">⚡</div>
            <p className="text-xs sm:text-sm font-medium text-white/60 text-center leading-snug">Label Claude Code terminals<br /><span className="text-xs text-white/30 font-normal">(with <code className="text-[#A78BFA]">/statusline</code>)</span></p>
          </div>
        </div>

        <div className="mt-6 animate-scroll-bounce text-white/20">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M6 9l6 6 6-6" />
          </svg>
        </div>
      </section>

      <div id="demo-section" className="snap-section">
        <HeroDemo />
      </div>

      {/* Features */}
      <section className="relative z-10 px-6 sm:px-8 py-16 sm:py-24 max-w-6xl mx-auto">
        <ScrollReveal>
          <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold text-center mb-3 sm:mb-4">
            Everything you need
          </h2>
          <p className="text-center text-white/35 mb-12 sm:mb-16 max-w-xl mx-auto text-sm sm:text-base">
            A complete voice dictation and screenshot context system for every app on your Mac.
          </p>
        </ScrollReveal>

        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4 sm:gap-6">
          <ScrollReveal delay={0}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                  <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                  <line x1="12" x2="12" y1="19" y2="22" />
                </svg>
              }
              title="On-Device STT"
              description="Apple's neural speech engine runs entirely on your Mac. Your voice never leaves your machine."
            />
          </ScrollReveal>
          <ScrollReveal delay={80}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect width="14" height="8" x="5" y="2" rx="2" />
                  <rect width="20" height="8" x="2" y="14" rx="2" />
                  <path d="M6 6h.01" />
                  <path d="M2 18h.01" />
                </svg>
              }
              title="Global Hotkey"
              description="fn+Space or Ctrl+Shift+Space toggles recording from any app. No clicking needed."
            />
          </ScrollReveal>
          <ScrollReveal delay={160}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                  <path d="m15 5 4 4" />
                </svg>
              }
              title="Auto-Paste"
              description="Transcribed text is automatically pasted into whatever text field has focus. Seamless."
            />
          </ScrollReveal>
          <ScrollReveal delay={0}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <rect width="18" height="14" x="3" y="5" rx="2" />
                  <circle cx="8.5" cy="10.5" r="1.5" />
                  <path d="m21 15-5-5L5 21" />
                </svg>
              }
              title="AI Chat Images"
              description="Open the purple image button to drag recent Desktop screenshots into your AI chat, or click one to paste it."
            />
          </ScrollReveal>
          <ScrollReveal delay={80}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10" />
                  <path d="m9 12 2 2 4-4" />
                </svg>
              }
              title="100% Private"
              description="All processing happens locally. No data is sent anywhere, ever. No account needed."
            />
          </ScrollReveal>
          <ScrollReveal delay={160}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <circle cx="12" cy="12" r="10" />
                  <line x1="2" x2="22" y1="12" y2="12" />
                  <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
                </svg>
              }
              title="11 Languages"
              description="English, Spanish, French, German, Japanese, Chinese, Portuguese, Italian, Korean and more."
            />
          </ScrollReveal>
          <ScrollReveal delay={0}>
            <FeatureCard
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              }
              title="Zero Cost, Forever"
              description="No subscriptions, no API keys, no accounts. Download and use with unlimited dictation."
            />
          </ScrollReveal>
        </div>
      </section>

      {/* How it works */}
      <section className="relative z-10 px-6 sm:px-8 py-16 sm:py-24 max-w-4xl mx-auto">
        <ScrollReveal>
          <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold text-center mb-12 sm:mb-16">
            How it works
          </h2>
        </ScrollReveal>

        <div className="space-y-8 sm:space-y-12">
          <ScrollReveal delay={0}><Step number="1" title="Download & open" description="Download the zip, unzip it, and move VibeTalk to your Applications folder. Double-click to open. If macOS says it can't verify the app, go to System Settings → Privacy & Security and click 'Open Anyway'." /></ScrollReveal>
          <ScrollReveal delay={100}><Step number="2" title="Grant permissions" description="The app will ask for Microphone, Speech Recognition, and Accessibility access. Say yes to all three — this lets VibeTalk hear you, transcribe your voice, and paste text where you're typing." /></ScrollReveal>
          <ScrollReveal delay={200}><Step number="3" title="Click any text field & press fn+Space" description="Click into any text box — a browser, Slack, VS Code, Notes, anywhere. Then press fn+Space (or Ctrl+Shift+Space) and start talking." /></ScrollReveal>
          <ScrollReveal delay={300}><Step number="4" title="Press fn+Space again — done" description="When you're done speaking, press the hotkey again. Your words are transcribed on your Mac and pasted right where your cursor was. That's it." /></ScrollReveal>
          <ScrollReveal delay={400}><Step number="5" title="Drop screenshots into AI chat" description="Click the purple image button to open recent Desktop screenshots. Drag one into your AI chat, or click it to paste." /></ScrollReveal>
        </div>
      </section>

      {/* Pill preview — draggable */}
      <DraggablePill />

      {/* Download CTA */}
      <section
        id="download"
        className="relative z-10 px-6 sm:px-8 py-20 sm:py-28 max-w-3xl mx-auto text-center"
      >
        <ScrollReveal>
          {/* Decorative ring */}
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div className="w-[300px] h-[300px] sm:w-[500px] sm:h-[500px] rounded-full border border-[#7359F2]/10 animate-spin-slow" />
          </div>

          <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-3 sm:mb-4 relative">
            Ready to speak?
          </h2>
          <p className="text-white/35 mb-8 sm:mb-10 max-w-xl mx-auto text-sm sm:text-base relative">
            Download VibeTalk for free. No account, no limits, no catch.
          </p>

          <div className="flex flex-col items-center gap-4 relative">
            <InstallButtons size="lg" onOpenModal={() => setModalOpen(true)} />
            <p className="text-xs text-white/20">Open source &middot; MIT license &middot; macOS 13+</p>
            <p className="text-xs text-white/15 max-w-sm text-center">A hobbyist open source project — feel free to adjust and use at your own risk.</p>
          </div>
        </ScrollReveal>
      </section>

      {/* Ko-fi Support */}
      <section className="relative z-10 px-6 sm:px-8 py-20 sm:py-28 max-w-3xl mx-auto text-center">
        <ScrollReveal>
          <div className="rounded-3xl border border-[#7359F2]/25 bg-gradient-to-br from-[#7359F2]/15 via-[#111117]/80 to-[#A78BFA]/10 backdrop-blur-xl p-10 sm:p-14 shadow-[0_0_80px_rgba(115,89,242,0.15)]">
            <div className="text-5xl sm:text-6xl mb-6">&#9749;</div>
            <h2 className="text-2xl sm:text-3xl md:text-4xl font-bold mb-5">
              Buy me a{" "}
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#7359F2] to-[#A78BFA]">
                coffee
              </span>
            </h2>
            <p className="text-base sm:text-lg text-white/45 max-w-xl mx-auto mb-10 leading-relaxed">
              VibeTalk is free and always will be. But building and maintaining
              it takes time. If it&apos;s saved you from typing, a coffee goes a
              long way.
            </p>
            <a
              href="https://ko-fi.com/kiki_ai"
              target="_blank"
              rel="noopener noreferrer"
              className="btn-shine inline-flex items-center gap-3 px-10 py-5 rounded-2xl bg-gradient-to-r from-[#7359F2] to-[#6344E0] hover:from-[#8B6FF5] hover:to-[#7359F2] transition-all text-lg sm:text-xl font-semibold text-white shadow-[0_0_60px_rgba(115,89,242,0.35)] hover:shadow-[0_0_100px_rgba(115,89,242,0.5)]"
            >
              <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                <path d="M23.881 8.948c-.773-4.085-4.859-4.593-4.859-4.593H.723c-.604 0-.679.798-.679.798s-.082 7.324-.022 11.822c.164 2.424 2.586 2.672 2.586 2.672s8.267-.023 11.966-.049c2.438-.426 2.683-2.566 2.658-3.734 4.352.24 7.422-2.831 6.649-6.916zm-11.062 3.511c-1.246 1.453-4.011 3.976-4.011 3.976s-.121.119-.31.023c-.076-.057-.108-.09-.108-.09-.443-.441-3.368-3.049-4.034-3.954-.709-.965-1.041-2.7-.091-3.71.951-1.01 3.005-1.086 4.363.407 0 0 1.565-1.782 3.468-.963 1.904.82 1.832 3.011.723 4.311z"/>
              </svg>
              Support on Ko-fi &#x2764;&#xFE0F;
            </a>
          </div>
        </ScrollReveal>
      </section>

      {/* Disclaimer / Terms */}
      <section className="relative z-10 px-6 sm:px-8 py-10 max-w-3xl mx-auto text-center border-t border-white/[0.04]">
        <p className="text-[11px] font-bold uppercase tracking-widest text-white/20 mb-4">Disclaimer &amp; Terms</p>
        <p className="text-xs text-white/30 leading-relaxed max-w-2xl mx-auto">
          VibeTalk is a free, hobbyist open source project provided <strong className="text-white/40">as-is</strong> with no warranties of any kind, express or implied.{" "}
          <strong className="text-white/40">Use at your own risk.</strong>{" "}
          By downloading or running this software you agree that the author(s) are not responsible or liable for any damages, data loss, security issues, or other consequences arising from its use.{" "}
          Always review the source code on{" "}
          <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" className="text-[#A78BFA]/60 hover:text-[#A78BFA] transition-colors underline underline-offset-2">GitHub</a>{" "}
          before building and running any software on your machine.{" "}
          This is not professional software — it is a personal side project released under the MIT license for the community.
        </p>
      </section>

      {/* Footer */}
      <footer className="relative z-10 border-t border-white/[0.04] py-6 sm:py-8 px-6 sm:px-8 text-center">
        <p className="text-xs sm:text-sm text-white/20">
          <a href="https://vibe-talk.fun/" className="hover:text-white/40 transition-colors">
            vibe-talk.fun
          </a>
          {" "}&middot;{" "}
          Free &amp; open source &middot; Built with
          Swift &amp; Apple Speech
        </p>
      </footer>
    </main>
  );
}

function InteractivePillDemo() {
  const [isRecording, setIsRecording] = useState(false);
  const [transcribedText, setTranscribedText] = useState("");
  const [screenshotsOpen, setScreenshotsOpen] = useState(false);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [dragging, setDragging] = useState(false);
  const dragStart = useRef({ x: 0, y: 0 });
  const posStart = useRef({ x: 0, y: 0 });

  const handleMicClick = () => {
    if (!isRecording) {
      setIsRecording(true);
      setTranscribedText("");
      setTimeout(() => {
        setIsRecording(false);
        setTranscribedText("Build me an HTML calculator that's super nice and modern");
      }, 2000);
    }
  };

  const onPointerDown = (e: React.PointerEvent) => {
    if ((e.target as HTMLElement).closest("[data-pill-action]")) return;
    setDragging(true);
    dragStart.current = { x: e.clientX, y: e.clientY };
    posStart.current = { x: pos.x, y: pos.y };
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragging) return;
    setPos({
      x: posStart.current.x + e.clientX - dragStart.current.x,
      y: posStart.current.y + e.clientY - dragStart.current.y,
    });
  };

  const onPointerUp = (e: React.PointerEvent) => {
    if (!dragging) return;
    setDragging(false);
    try { (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId); } catch {}
  };

  return (
    <div className="mt-8 sm:mt-10 flex justify-center animate-pill-pop-in" style={{ animationDelay: '0.7s' }}>
      <div className="inline-flex flex-col items-center gap-3 w-full max-w-sm">
        {/* Pill Container */}
        <div className="flex items-center gap-3">
          <div
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
            style={{
              transform: `translate(${pos.x}px, ${pos.y}px)`,
              cursor: dragging ? "grabbing" : "grab",
              touchAction: "none",
              userSelect: "none",
            }}
            className="inline-flex flex-col items-center"
          >
          <div className="inline-flex items-center gap-2 pl-2 pr-3 py-2 rounded-full bg-[#111117] border border-[#7359F2]/20 shadow-[0_0_0_1px_rgba(115,89,242,0.08),0_8px_32px_rgba(0,0,0,0.4)] animate-pill-glow transition-shadow">
            {/* Mic button */}
            <button
              data-pill-action="true"
              onClick={handleMicClick}
              onPointerDown={(e) => e.stopPropagation()}
              className="w-8 h-8 rounded-full bg-[#7359F2] flex items-center justify-center flex-shrink-0 hover:bg-[#8B6FF5] transition-colors cursor-pointer"
            >
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
            </button>
            <span className="text-sm text-white/40 px-1 flex-1 text-left">
              {isRecording ? "Recording..." : "Click mic or fn+Space"}
            </span>
            {/* Screenshots button */}
            <div className="relative">
              <button
                type="button"
                data-pill-action="true"
                onClick={() => { setScreenshotsOpen((o) => !o); setHistoryOpen(false); }}
                onPointerDown={(e) => e.stopPropagation()}
                aria-label="Open recent screenshots"
                className={`w-[26px] h-[26px] rounded-full flex items-center justify-center flex-shrink-0 transition-all ${
                  screenshotsOpen ? "bg-[#7359F2]/75" : "bg-[#7359F2]/40 hover:bg-[#7359F2]/60"
                }`}
              >
                <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ opacity: 0.92 }}>
                  <rect width="18" height="14" x="3" y="5" rx="2" />
                  <circle cx="8.5" cy="10.5" r="1.5" />
                  <path d="m21 15-5-5L5 21" />
                </svg>
              </button>
              {screenshotsOpen && (
                <div className="absolute bottom-full right-0 mb-3 z-50 w-[300px] rounded-2xl border border-[#7359F2]/24 bg-[#111117]/98 p-3 text-left shadow-[0_-8px_40px_rgba(0,0,0,0.6)] backdrop-blur-xl">
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
                onClick={() => { setHistoryOpen((o) => !o); setScreenshotsOpen(false); }}
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
                <div className="absolute bottom-full right-0 mb-3 z-50 w-[240px] rounded-2xl border border-[#7359F2]/24 bg-[#111117]/98 p-3 text-left shadow-[0_-8px_40px_rgba(0,0,0,0.6)] backdrop-blur-xl">
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

          </div>

          {/* Arrow + label — to the right of the pill */}
          <div className="hidden sm:flex items-center gap-2 text-[#B7A6FF]/70 flex-shrink-0">
            <svg width="40" height="28" viewBox="0 0 40 28" fill="none" className="flex-shrink-0">
              <path d="M36 10 C24 4 12 8 4 18" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round"/>
              <path d="M10 11 L4 18 L12 20" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
            </svg>
            <span className="text-xs font-semibold text-white/48 max-w-[100px] leading-tight text-left">This is what it actually looks like at the bottom of your screen</span>
          </div>
        </div>

        {/* Transcription Result */}
        {transcribedText && (
          <div className="w-full rounded-lg bg-[#7359F2]/10 border border-[#7359F2]/30 p-3 animate-in fade-in">
            <p className="text-xs sm:text-sm text-white/80">{transcribedText}</p>
          </div>
        )}
      </div>
    </div>
  );
}

function FeatureCard({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="feature-card p-5 sm:p-6 rounded-2xl bg-[#111117]/80 backdrop-blur-sm border border-white/[0.05]">
      <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#7359F2]/20 to-[#A78BFA]/10 flex items-center justify-center text-[#A78BFA] mb-4">
        {icon}
      </div>
      <h3 className="text-base sm:text-lg font-semibold mb-2">{title}</h3>
      <p className="text-xs sm:text-sm text-white/35 leading-relaxed">{description}</p>
    </div>
  );
}

function Step({
  number,
  title,
  description,
}: {
  number: string;
  title: string;
  description: string;
}) {
  return (
    <div className="flex gap-4 sm:gap-6 items-start">
      <div className="shrink-0 w-10 h-10 sm:w-12 sm:h-12 rounded-full bg-gradient-to-br from-[#7359F2]/20 to-[#7359F2]/5 border border-[#7359F2]/25 flex items-center justify-center text-[#A78BFA] font-bold text-sm">
        {number}
      </div>
      <div>
        <h3 className="text-base sm:text-lg font-semibold mb-1">{title}</h3>
        <p className="text-white/35 leading-relaxed text-sm sm:text-base">{description}</p>
      </div>
    </div>
  );
}
