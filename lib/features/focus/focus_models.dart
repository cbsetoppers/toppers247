// ─────────────────────────────────────────────────────────────────────────────
// Focus Companion — Core Enums and Models
// Equivalent to Mood.swift + DistractionPhase enum from FocusMoodController.swift
// ─────────────────────────────────────────────────────────────────────────────

enum FocusMood { normal, happy, curious, angry, tired }

enum DistractionPhase {
  none,
  searching, // 0-3s: curious, timer frozen
  angry,     // 3-6s: angry, shows "DISTRACTED"
  critical,  // 6-9s: angry + red eyes, shaking "DISTRACTED"
  reset,     // 9s+:  timer reset, tired then curious
}

enum TimerMode { idle, running, completed }
enum TimerDuration { free, fifteen, twentyFive, fortyfive, sixty, custom }
