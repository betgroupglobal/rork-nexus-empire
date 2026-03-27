---
description: Repository Information Overview
alwaysApply: true
---

# Repository Information Overview

## Repository Summary
**Nexus** is a comprehensive "Empire Command Center" designed for iOS, providing a unified interface for managing multiple business entities (Persons, Ltds, Trusts). The system integrates financial data, communication channels (SMS, Calls, Voicemail), and alert management into a single dashboard. It features a native Swift iOS application and a TypeScript-based backend powered by Bun, Hono, and tRPC.

## Repository Structure
- **Nexus/**: Primary iOS application source code (SwiftUI).
- **Nexus.xcodeproj/**: Xcode project configuration.
- **NexusWidget/**: iOS Home Screen widget extension.
- **backend/**: Bun-powered backend providing tRPC API endpoints.
- **app/**: Small integration layer (Expo Router / Native Intent).
- **NexusTests/ & NexusUITests/**: Native testing suites for the iOS application.

### Main Repository Components
- **iOS Application**: Native SwiftUI app for dashboarding, entity management, and unified communications.
- **Backend API**: Stateless tRPC server handling entities, communications, and authentication.
- **Widget Extension**: Quick-glance dashboard metrics for the iOS Home Screen.

## Projects

### Nexus iOS App
**Configuration File**: `Nexus.xcodeproj`, `Nexus/Config.swift`

#### Language & Runtime
**Language**: Swift  
**Version**: Swift 5.10+ / iOS 17.0+  
**Build System**: Xcode (PBX)  
**Package Manager**: Swift Package Manager (integrated in Xcode)

#### Dependencies
**Main Dependencies**:
- SwiftUI (UI Framework)
- Foundation (Base Utilities)
- Swift Testing (Modern testing framework)

#### Build & Installation
```bash
# Open in Xcode
open Nexus.xcodeproj
# Build via xcodebuild (CLI)
xcodebuild -scheme Nexus -workspace Nexus.xcworkspace build
```

#### Testing
**Framework**: Swift Testing (`import Testing`)
**Test Location**: `NexusTests/`, `NexusUITests/`
**Naming Convention**: `*Tests.swift`
**Configuration**: `Nexus.xcodeproj` test targets

**Run Command**:
```bash
# Run tests in Xcode (Cmd+U) or via CLI
xcodebuild test -scheme Nexus -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

### Nexus Backend
**Configuration File**: `backend/hono.ts`, `backend/trpc/app-router.ts`

#### Language & Runtime
**Language**: TypeScript  
**Version**: Bun v1.3.9+  
**Build System**: Bun Runtime  
**Package Manager**: Bun (`bun install`)

#### Dependencies
**Main Dependencies**:
- `hono`: Web framework
- `@trpc/server`: Type-safe API layer
- `zod`: Schema validation
- `superjson`: Data serialization
- `crypto`: Web Crypto API (native in Bun)

#### Build & Installation
```bash
# Install dependencies
bun install
# Start the backend
bun run backend/hono.ts
```

#### Main Files & Resources
- **Entry Point**: `backend/hono.ts`
- **API Router**: `backend/trpc/app-router.ts`
- **Mock DB**: `backend/db.ts` (Realistic sample data for 8 entities)
- **Auth**: `backend/trpc/routes/auth.ts` (JWT/PBKDF2 implementation)

---

### Nexus Widget
**Type**: iOS App Extension

#### Language & Runtime
**Language**: Swift  
**Version**: iOS 17.0+  
**Build System**: Xcode

#### Key Resources
- **Main Files**: `NexusWidget/NexusWidget.swift`, `NexusWidget/NexusWidgetBundle.swift`
- **Configuration**: `NexusWidget/Info.plist`

#### Usage & Operations
The widget provides "Total Firepower" (combined credit) and "Urgent Action" counts directly on the iOS Home Screen. It uses `WidgetKit` and `SwiftUI` for rendering.

#### Validation
**Testing Approach**: UI Testing via `NexusUITests` to verify widget presence and deep-linking.
