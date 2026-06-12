# 📋 Focus Quest — Features

A brief overview of implemented features in the Focus Quest app.

---

## ✅ Quest Management

- **Create Quests** — Low-friction task creation with title, description, and due dates
- **Categories** — Organize quests by Work, Personal, Learning, or Other
- **Energy Levels** — Tag tasks by energy requirement (Minimal → Intense) to match your current capacity
- **Status Tracking** — Pending, In Progress, Completed, and Cancelled states
- **Repeating Quests** — Set daily, weekly, or monthly repeats with specific day selection
- **Active/Completed Tabs** — Easily view active quests vs completed history

---

## ⏱️ Sub-Quests (Micro-Tasks)

- **5-Minute Limit** — All sub-quests capped at 5 minutes to combat ADHD overwhelm
- **Bite-Sized Actions** — Break large quests into tiny, actionable steps
- **Progress Tracking** — Track completion of individual sub-quests

---

## 🎯 Focus Sessions

- **Pomodoro-Style Timer** — Structured focus sessions with planned durations
- **Session Types** — Focus, Short Break, and Long Break modes
- **Pause & Resume** — Pause sessions and track total paused time
- **Strict Mode** — Optional "No Pause" mode for deep focus
- **State Persistence** — Timer saves its state; close the app and return right where you left off
- **Session History** — Track completed and interrupted sessions

---

## 🏆 Progress & Gamification

- **XP System** — Earn experience points for completing quests and focus sessions (1 XP per focus minute, 50 XP per quest)
- **Leveling** — Progressive level system with increasing XP requirements
- **Streaks** — Daily activity tracking with current and longest streak; repeating quests track per-quest streaks (daily, weekly, and monthly)
- **Achievements** — Unlock badges for milestones:
  - First Quest, Quest Master (10+), Quest Legend (100+)
  - First Focus, Focus Hour (1h+), Focus Marathon (10h+)
  - Streak milestones (7-day, 30-day)
  - Level milestones (5, 10, 25)

---

## 🎨 Personalized Experience

- **Dynamic Greetings** — Time-based greetings (Good Morning, Good Afternoon, Good Evening)
- **User Display Name** — Shows authenticated user's name on the home screen
- **Welcoming Interface** — Makes the app feel personal and engaging

---

## 🎨 Theme System

- **Light & Dark Mode** — Full theme support with smooth switching
- **Persistent Preference** — Theme choice saved locally
- **System Default** — Option to follow device theme

---

## 🔐 Authentication & Sync

- **Google Sign-In** — Secure authentication to save your progress
- **Cloud Sync** — Seamlessly sync your data across multiple devices via Firebase
- **Offline + Online** — Continue working offline; data syncs automatically when back online
- **Guest Mode** — Try the full app without creating an account (data stays local)

---

## 💾 Data & Storage

- **Local-First Architecture** — Instant interaction speed using Sembast local database
- **Cloud Backup** — Optional Firestore backup to prevent data loss
- **Privacy Focused** — Your data is yours; we only store what's needed for sync

---

## 🔔 Smart Notifications

- **Timer Awareness** — Persistent notifications to keep you aware of your focus time
- **Pause Alerts** — Gentle reminders if you've left the timer paused for too long
- **Completion Alerts** — Get notified when your session or break ends

## 🌍 Internationalization

- **Multi-Language Support** — English and Spanish included
- **Easily Extensible** — ARB-based system for adding new languages

---

## 📱 Platform Support

- Android
- iOS
- macOS
- Linux
- Windows
- Web

---

*For technical details and architecture, see the main [README.md](README.md) and [HLD](hld.md).*
