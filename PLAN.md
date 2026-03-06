# Nexus — Empire Command Center for iOS


## Features

### Dashboard (Command Center)
- **Total Firepower** display showing combined credit across all entities with animated counter
- **Monthly Burn Rate** showing infrastructure costs with trend indicator
- **Urgent Actions** count with color-coded badges (red for critical, yellow for attention, green for clear)
- **Quick Stats Row** — entities count, active comms, unread messages, health overview
- Pull-to-refresh with haptic feedback

### Entity Radar
- Each entity (Person / Ltd / Trust) has a **Health Score** (0–100) with animated circular gauge
- Color-coded status: Green (80–100), Yellow (50–79), Red (0–49)
- Entity cards showing: name, type, credit limit, utilisation %, last activity date, assigned phone/email
- **Smart Search** with instant filtering by name, type, or status
- Filter chips: All / Active / Dormant / At Risk
- Tap an entity → full detail view with activity timeline, linked comms, and credit history
- Swipe actions: Archive, Flag, Quick Edit

### Comms Citadel (Unified Inbox)
- Unified view of all SMS, calls, voicemails across all entity numbers
- Each message auto-tagged with entity name and badge color
- Tabs: All / SMS / Calls / Voicemails
- Voicemail entries show transcription text + audio duration
- Unread indicator dots and timestamp formatting
- Tap to expand full message thread per entity

### Email Router (Empire Inbox)
- Unified email view with entity auto-tagging
- Smart categories: Statements / Approvals / IRD Notices / General
- Preview cards showing sender, subject, entity tag, and snippet
- Auto-archive indicator for 90+ day old messages
- Flag system for messages containing dollar amounts or keywords

### Alert Brain (Notifications Center)
- Timeline of all alerts: utilisation warnings, ClearScore drops, dormant entities, new comms
- Priority levels with distinct icons and colors
- Filter by alert type
- Each alert links directly to the relevant entity or message

### Settings & Configuration
- Entity management (add/edit/archive)
- Alert rules configuration
- Theme preference (light/dark/system)
- Data export option

### Home Screen Widget
- **Small Widget** — Total Firepower number + urgent action count
- **Medium Widget** — Firepower, burn rate, top 3 urgent actions with entity names
- Tapping the widget opens the relevant section in the app

---

## Design

- **Clean professional** aesthetic — adaptive light/dark mode with system blue tint
- Dashboard uses **card-based layout** with subtle shadows and rounded corners on grouped background
- Entity health scores shown as **animated ring gauges** (green/yellow/red gradient)
- Firepower displayed in large **bold SF Pro** with animated counting effect
- Comms inbox uses a **native List** style similar to Apple Messages
- Material backgrounds (`.ultraThinMaterial`) for floating summary bars
- Staggered fade-in animations when views load
- Spring animations on card interactions
- Haptic feedback on key actions (archiving, flagging, refreshing)
- Tab bar with 5 tabs: Dashboard, Entities, Comms, Inbox, Alerts
- SF Symbols throughout — `shield.checkered`, `antenna.radiowaves.left.and.right`, `envelope.badge`, `bell.badge`, `chart.bar.xaxis`

---

## Screens

1. **Dashboard** — Hero card with total firepower, burn rate, and urgent actions list. Scrollable with quick-glance entity health summary
2. **Entities** — Searchable list of all entities with health score rings, filter chips, and swipe actions. Tap → Entity Detail
3. **Entity Detail** — Full profile: health gauge, credit info, utilisation chart, activity timeline, linked numbers/emails
4. **Comms** — Unified message inbox with tabs (All/SMS/Calls/Voicemails), entity tags on each item
5. **Email Inbox** — Categorised email list with smart tags, previews, and flag indicators
6. **Alerts** — Chronological alert timeline with type filters and direct entity links
7. **Settings** — Entity management, alert rules, preferences
8. **Add/Edit Entity** — Sheet with fields for name, type, credit limit, assigned numbers, emails

---

## App Icon

- Dark navy blue background with a subtle radial gradient toward the center
- A minimal white shield icon with a small network/nexus node pattern inside
- Clean, professional, and authoritative — like a premium financial app

---

## Data

- All data is **realistic sample data** pre-loaded on first launch (8 entities across Person/Ltd/Trust types)
- Stored locally using on-device persistence
- Sample comms, emails, and alerts pre-populated to showcase the full experience
