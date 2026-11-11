# Hybrix

Hybrix is a native iOS fitness tracker built with SwiftUI and SwiftData, designed for autoregulated periodization, gym-specific equipment adaptation, superset pairing, and dynamic workout management.

## Features

- **Periodization & Load Autoregulation:**
  - Double-progression logic with target RIR guidance.
  - Plate-specific increments (2.5 lbs) vs. discrete dumbbell and kettlebell step logic.
  - Dynamic intra-workout load adjustments based on effort and rep targets.
- **Gym Profiles & Equipment Inventory:**
  - Multi-gym management with customizable equipment presets (Commercial, Garage Rack, Hotel, Travel).
  - Bar weight customization (Olympic, Technique, Smith Machine, EZ Curl Bar, Trap Bar).
  - Available plate breakdown and kettlebell inventory tracking.
  - Non-destructive gym and custom lift deletion with immutable history snapshots.
- **Superset & Workout Order Management:**
  - Drag-and-drop superset grouping with automatic adjacent clustering.
  - Contiguous superset joining and time-budget optimization.
- **Live Activity & Widgets:**
  - Lock Screen Live Activity widget showing active set, target RIR, and rest timers.
  - iOS Dynamic Island integration.

## Architecture

- **Platform:** iOS 17.0+
- **Frameworks:** SwiftUI, SwiftData, ActivityKit, WidgetKit
- **Patterns:** MVVM / Services-oriented periodization and time-budget engines

## Requirements

- Xcode 15+
- iOS 17.0+ Simulator or Device
