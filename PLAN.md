# Nexus — War Room Command Center for iOS


## Features

### Dashboard (War Room Command Center)
- [x] **Current Applications Total** — massive animated counter showing every live credit application across all subjects
- [x] **Longest Active** tile — subject + application running longest (name + exact days active + bank), pulses when >45 days
- [x] **Email Tile** — unified unread/pending email count, tap routes to Email Router
- [x] **SMS Tile** — unified unread SMS count, tap routes to Comms Citadel
- [x] **Urgent Actions** — live count with color-coded badges (red critical, yellow attention, green clear)
- [x] **Quick Stats Row** — Total Subjects, Active Comms (last 24h), Unread Messages
- [x] Pull-to-refresh with haptic feedback

### Subject Database (Replaces Entity Radar)
- [x] Every subject rendered as a card with **Credit Score (0–100)** in animated circular gauge
- [x] Color-coded accents: Green (80–100), Yellow (50–79), Red (0–49)
- [x] Subject cards: Name | Credit Score + color ring | Banks Applied | Progress % (bar + number) | Last Activity | Assigned Phone/Email
- [x] **Smart Search** — instant filtering by name, bank, or progress %
- [x] Filter chips: All | Active | Pending | At Risk | High Progress
- [x] Context menu actions: Archive, Flag
- [x] Tap any subject → clean two-section detail view:
  - **Personal Information** (key-value grid: Name | DOB | Address | ID | Contacts)
  - **Credit Application Progress** (tabular grid): Bank | Product | Status | Progress % | Submitted | Last Update | Next Action | Documents

### Comms Citadel (Unified Inbox)
- [x] All SMS, calls, voicemails across every subject number
- [x] Messages auto-tagged with subject name + credit score color badge
- [x] Tabs: All | SMS | Calls | Voicemails (live counters)
- [x] Voicemail cards: transcription + duration + playhead
- [x] Tap expands full thread scoped to that subject

### Email Router (Empire Inbox)
- [x] Unified inbox with automatic subject tagging
- [x] Smart categories: Statements | Approvals | Bank Notices | IRD | General
- [x] Preview cards: sender | subject tag | snippet + $ amount highlight if present
- [x] Flag/archive swipe actions

### Alert Brain (Notifications Center)
- [x] Timeline of all alerts tied to specific subjects (stalled apps, score drops, verification blocks, new comms, utilisation spikes)
- [x] Priority icons + colors (red critical, orange warning, blue info)
- [x] Filter by type
- [x] Every alert one-taps directly into the subject's detail view

### Settings & Configuration
- [x] Subject management (add/edit/archive)
- [x] CrazyTel integration
- [x] Email account management
- [x] Theme: Light / Dark / **Void** (#000000 base + red bleed on critical) — Void is default
- [x] Backend status indicator + retry

### Home Screen Widget
- [x] **Small**: Current Applications Total + Urgent Actions count
- [x] **Medium**: Current Applications + Longest Active subject name + top 3 urgent items

---

## Design

- **Void theme default** — pure black (#000) base with red accent on critical states, maximum contrast for green/yellow/red score indicators
- Dashboard uses **card-based layout** with animated counter hero section
- Subject credit scores shown as **animated ring gauges** (green/yellow/red)
- Applications counter displayed in large **bold SF Pro Rounded** with animated counting effect
- Comms inbox uses **native List** style with subject name + score color badges on each message
- Staggered fade-in animations when views load
- Spring animations on gauge fills and card interactions
- Haptic feedback on key actions (refreshing, flagging)
- Tab bar with 5 tabs: War Room, Subjects, Comms, Email, Alerts
- SF Symbols throughout

---

## Screens

1. **War Room** — Hero counter for current applications, longest active tile, urgent actions, quick stats
2. **Subjects** — Searchable card list with credit score gauges, filter chips, context menus. Tap → Subject Detail
3. **Subject Detail** — Two-section layout: Personal Information grid + Credit Application Progress table with status badges and progress bars
4. **Comms Citadel** — Tabbed message inbox (All/SMS/Calls/Voicemails) with subject tags and live counters
5. **Email Router** — Categorised email list with smart tags, subject badges, $ amount highlights
6. **Alert Brain** — Chronological alert timeline with type filters and direct subject links
7. **Settings** — Integrations, theme, backend status, data overview

---

## Models

- **Subject** (replaces Entity): id, name, type (Person/Ltd/Trust), status (Active/Pending/At Risk/Archived), creditScore (0-100), assignedPhone, assignedEmail, lastActivityDate, dateOfBirth, address, idNumber, applications[]
- **CreditApplication**: id, bank, product, status (Submitted/In Review/Approved/Declined/Docs Needed/Stalled), progressPercent, submittedDate, lastUpdateDate, nextAction, documents
- **Communication**: id, type, sender, content, timestamp, isRead, phoneNumber, duration, transcription, subjectId, subjectName
- **EmailMessage**: id, sender, senderAddress, subject, snippet, category (Statement/Approval/Bank Notice/IRD/General), timestamp, isRead, isFlagged, containsDollarAmount, subjectId, subjectName
- **NexusAlert**: id, type (Stalled App/Score Drop/Verification/New Comm/Utilisation), priority (Critical/Warning/Info), title, message, timestamp, isRead, subjectId, subjectName

---

## Data

- All data is **realistic sample data** pre-loaded on first launch (8 subjects across Person/Ltd/Trust types)
- Each subject has 1-3 credit applications with varied statuses
- 11 active applications total across all subjects
- Stored locally using on-device persistence with backend API fallback
- Sample comms, emails, and alerts pre-populated with subject linkage
