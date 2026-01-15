# 📐 High-Level Design (HLD) – FocusQuest (Phase 1)

> **Scope:** Phase 1 (MVP only)
> **Local Database:** **Sembast** (Local-first, offline)
> **Cloud Sync:** Enabled but User‑Switchable (Firestore)

---

## 1. System Overview

FocusQuest is a **dopamine-driven productivity planner** designed for users with ADHD, focusing on:

* Executive dysfunction
* Time blindness
* Task initiation paralysis

Phase 1 prioritizes **speed, offline reliability, and low cognitive load**.

---

## 2. Architecture Style

**Local-First with Switchable Cloud Sync & Conditional Auth (Phase 1)**

```
Flutter UI
       │
Riverpod State Layer
       │
Domain / Business Logic
       │
Repository Layer
       │
Sembast (Local DB)
       │
Sync Controller (On / Off)
       │
Firebase Auth (Only if Sync ON)
       │
Firestore (Cloud Backup)
```

### Key Principles

- Sembast remains the **single source of truth**
- Firebase Auth is **required only when cloud sync is enabled**
- Users can use the app **without login** in offline-only mode
- Cloud sync is fully **opt-in and switchable**
- App works 100% offline when sync is disabled
- Sync and auth failures must never block core flows

---

## 3. Technology Stack (Phase 1)

| Layer | Technology |
|-------|------------|
| UI | Flutter (Dart) |
| State Management | Riverpod |
| Local Storage | **Sembast** |
| Notifications | awesome_notifications |
| Animations | Lottie |
| Haptics | flutter_haptic |
| Auth | **Firebase Auth (required only for cloud sync)** |

---

## 4. Module Breakdown

### 4.1 Presentation Layer (Flutter UI)

#### Responsibilities

- Render anti-shame, low-friction UI
- Maximum **3 taps** to create a task
- Heavy use of animation + haptics for dopamine

#### Core Screens

- Today's Quest List
- Focus Mode (Timer)
- Brain Dump Overlay
- End-of-Day Micro Journal
- XP / Level Progress

UI **never accesses Sembast directly**.

---

### 4.2 State Management Layer (Riverpod)

#### Responsibilities

- Provide reactive UI updates
- Abstract persistence details
- Manage focus and timer states

#### Key Providers

- `questListProvider`
- `activeQuestProvider`
- `focusSessionProvider`
- `energyLevelProvider`
- `journalProvider`

Providers depend only on **repository interfaces**, not Sembast itself.

---

### 4.3 Domain Layer (Quest Engine)

#### Core Concepts

| Entity | Description |
|--------|-------------|
| Quest | Primary task |
| SubQuest | Atomic 2–5 min step |
| FocusSession | Active work session |
| JournalEntry | Daily reflection |
| UserProgress | XP, level, streak |

#### Business Rules

- Tasks must support sub-quests
- XP awarded on completion
- No penalties for missed tasks
- Emergency breakdown allowed anytime

---

### 4.4 Focus Mode & Time-Blindness Defense

#### Components

- Pomodoro-style timer ("Mana")
- App lifecycle observer
- Persistent notifications

#### Flow

```
Start Focus
     ↓
Timer Running
     ↓
App Backgrounded? → Trigger Notification
     ↓
Session End → Complete / Extend
```

Focus state is **persisted in Sembast** to survive app restarts.

---

### 4.5 Notification Engine

#### Characteristics

- Persistent reminders
- Hard-to-ignore alerts
- Action-based notifications

#### Use Cases

- Task start nudges
- Focus abandonment alerts
- Timer completion

---

### 4.6 Local Data Layer (Sembast)

#### Why Sembast

- Pure Dart (no native bindings)
- Lightweight & simple
- Ideal for MVP and rapid iteration

#### Storage Design

- One local database per user
- Store-per-entity approach

#### Stores

- `quests`
- `subQuests`
- `focusSessions`
- `journalEntries`
- `userProgress`

#### Data Characteristics

- JSON-based documents
- Indexed by string IDs
- Timestamp-based updates

---

### 4.7 Repository Layer

#### Responsibilities

- Encapsulate Sembast queries
- Coordinate with Sync Controller
- Expose sync‑safe APIs to domain layer

#### Sync Awareness

- All writes go to **Sembast first**
- If sync is enabled:
  - Changes are queued for Firestore
  - Sync runs in background
- If sync is disabled:
  - No network calls are made

#### Example Responsibilities

- CRUD for quests
- Fetch today's tasks
- Persist focus session state
- Aggregate XP & streaks
- Emit change events for sync

---

## 5. Non-Functional Requirements (Phase 1)

| Concern | Strategy |
|---------|----------|
| Performance | Local-only reads/writes |
| Offline | Fully functional offline |
| Reliability | Persist focus state |
| Maintainability | Repository abstraction |
| Privacy | No cloud dependency |

---

## 6. Phase 1 Scope Control

### Included

- Quest management
- Focus mode
- Local persistence
- XP & leveling
- Micro journaling
- **Switchable cloud sync (backup & restore)**
- **Conditional Firebase authentication (only for sync)**

### Explicitly Excluded

- AI task planning
- Social features
- Body doubling
- Advanced analytics & ML

---

## 7. Phase 1 Success Criteria

- App works fully offline without login
- Login is required **only** when enabling sync
- Zero perceived latency
- Focus sessions survive restarts
- Users complete at least one task/day

---

## 8. Dependencies & Alternatives (Phase 1)

| Purpose | Primary Dependency | Popular Alternatives | Notes |
|---------|-------------------|---------------------|-------|
| UI Framework | Flutter | React Native, SwiftUI | Flutter best for animations |
| State Management | flutter_riverpod | Bloc, MobX | Compile-time safety |
| Local Database | sembast | Hive, Drift, Isar | Pure Dart, MVP-friendly |
| Cloud Database | cloud_firestore | Supabase, Appwrite | Used only if sync ON |
| Authentication | firebase_auth | Auth0, Clerk, Supabase Auth | Required only for sync |
| Core Firebase | firebase_core | — | Mandatory for Firebase stack |
| Notifications | awesome_notifications | flutter_local_notifications | Persistent alerts |
| Animations | lottie | Rive | Rive for future interactivity |
| Haptics | flutter_haptic | vibration | Simple abstraction |
