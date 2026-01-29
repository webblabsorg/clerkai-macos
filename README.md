# Clerk macOS Desktop Application

AI Legal Assistant for macOS - A floating, context-aware legal AI tool.

## Requirements

- macOS 12.0 (Monterey) or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Project Structure

```
Clerk/
├── App/                    # Application entry point and lifecycle
│   ├── ClerkApp.swift      # @main entry point
│   ├── AppState.swift      # Global state management
│   ├── FloatingPanel.swift # Floating window implementation
│   └── HotKeyManager.swift # Global hotkey handling
│
├── Views/                  # SwiftUI views
│   ├── MainContentView.swift
│   ├── Avatar/             # Minimized state (48x48 avatar)
│   ├── Compact/            # Compact toolbar state
│   ├── Expanded/           # Full panel with categories
│   ├── ToolExecution/      # Tool input/output views
│   ├── Settings/           # Preferences views
│   ├── Onboarding/         # First-run experience
│   └── Components/         # Reusable UI components
│
├── ViewModels/             # View models (MVVM)
│
├── Models/                 # Data models
│   ├── User.swift
│   ├── Tool.swift
│   ├── Language.swift
│   ├── DetectedContext.swift
│   ├── UsageStats.swift
│   └── ToolExecution.swift
│
├── Services/               # Business logic services
│   ├── Network/
│   │   └── APIClient.swift
│   ├── Storage/
│   │   ├── KeychainManager.swift
│   │   └── UserDefaultsManager.swift
│   ├── AI/
│   │   └── AIService.swift
│   ├── Context/
│   │   └── ContextDetectionService.swift
│   ├── AuthService.swift
│   └── ToolService.swift
│
├── Utilities/              # Helper utilities
│   ├── Logger.swift
│   └── Extensions.swift
│
└── Resources/              # Assets and localization
    ├── Colors.xcassets/    # Color assets
    └── Localization/       # String catalogs
```

## Building

### Using Swift Package Manager

```bash
cd dev/macos
swift build
swift run Clerk
```

### Using Xcode

1. Open `Clerk.xcodeproj` in Xcode
2. Select the "Clerk" scheme
3. Build and run (⌘R)

## Design System

### Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| Deep Black | `#0A0A0A` | Dark mode background |
| Deep White | `#FAFAFA` | Light mode background |
| Deep Cream | `#F5F0E8` | Warm light mode |
| Deep Chocolate | `#2C1810` | Warm dark mode |
| Accent Gold | `#C9A227` | Buttons, links, highlights |

### Typography Rules

- **Dark backgrounds** (Black, Chocolate): Use Deep White text
- **Light backgrounds** (White, Cream): Use Deep Black text

## Features

### UI States

1. **Minimized (Avatar)**: 48x48px floating avatar with breathing animation
2. **Compact (Toolbar)**: 320x56px quick action bar
3. **Expanded (Panel)**: 400x600px full tool browser
4. **Tool Execution**: 450x650px input/output view

### Global Hotkeys

- `⌘⇧C`: Toggle panel
- `⌘⇧S`: Quick summarize
- `⌘⇧R`: Quick risk check

### Context Detection

The app monitors the active application and detects:
- Document type (contract, brief, email, etc.)
- Selected text
- Window title

Based on context, it suggests relevant legal AI tools.

## Architecture

- **Pattern**: MVVM with Combine
- **State Management**: `AppState` singleton with `@Published` properties
- **Networking**: Async/await with `URLSession`
- **Storage**: Keychain for secrets, UserDefaults for preferences

## License

Proprietary - Clerk Legal AI
