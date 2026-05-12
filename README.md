# Expenses Tracker

A dark-themed personal finance management application built with Flutter and Firebase. Track income, expenses, accounts, debts, and financial reminders with full offline support.

## Features

### Finance Dashboard
Real-time overview of your financial status -- total balance across all accounts, monthly income and expenses with savings calculation, and recent transaction history in a single scrollable view.

### Account Management
Track multiple financial sources including cash, credit cards (Visa/Mastercard), and savings accounts. Each account displays its current balance with a clean card-based layout. Add, edit, or remove accounts through a dedicated screen.

### Income & Expense Tracking
Log transactions with categories (Food, Transport, Shopping, Bills, Entertainment, Salary, Freelance, etc.). Switch between income and expense views, search transactions by category or note, and view monthly summaries.

### Debt Ledger
Dual-ledger system tracking money you owe and money owed to you. Each entry records the other party, amount, and status. Automatic net balance calculation displayed at the top.

### Smart Reminders
Date-driven notification system for upcoming financial obligations. Each reminder includes a title, due date, and optional notes. The home screen dashboard shows the nearest alerts and the home widget displays the next 2 upcoming reminders.

### PageView Navigation
Swipe left or right to navigate between sections -- Dashboard, Accounts, Activity, Reminders, and Debts. The bottom navigation bar syncs with the current page and provides haptic feedback.

### Offline-First Architecture
Local SQLite caching ensures full functionality without internet connectivity. Data syncs automatically to Firebase when the connection is restored. No data loss during network interruptions.

### Android Home Screen Widgets
Four native Android widgets in a uniform 3x2 layout:

- **Finance Summary** -- Total balance with account list
- **Quick Actions** -- One-tap shortcuts for Income, Expense, Alert, and Debt
- **Recent Activity** -- Last 3 transactions with category and amount
- **Debts & Alerts** -- Owe/Owed totals plus nearest 2 upcoming reminders

Widgets update automatically via `WidgetService` whenever data changes in the app.

### Native Quick Add Dialog
A lightweight Android dialog overlay for quickly adding transactions without launching the full app. Accessible from the Quick Settings tile or home screen widget.

### GitHub-Style Dark Theme
Professional dark color palette inspired by GitHub's design system:

- Background: `#0D1117`
- Surface: `#161B22`
- Primary: `#58A6FF`
- Income: `#3FB950`
- Expense: `#F85149`
- Accent: `#D29922`

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart 3.x) |
| Backend | Firebase Auth, Firestore, Realtime Database |
| State Management | StatefulWidget + Streams |
| Local Storage | SQLite (via sqflite) |
| Native Android | Kotlin |
| Home Widgets | home_widget plugin |
| Connectivity | connectivity_plus |

## Architecture

The app follows a service-oriented architecture:

```
UI Layer (Flutter Screens)
    |
Service Layer (FirebaseService, AuthService, StorageService)
    |
Data Layer (Firebase Firestore + Local SQLite)
    |
Native Layer (Kotlin Widgets, Quick Add, Deep Links)
```

- `FirebaseService` handles all Firestore CRUD operations and exposes data as Dart Streams for real-time reactivity.
- `StorageService` mirrors Firebase collections locally via SQLite for offline access.
- `WidgetService` pushes data to native Android home screen widgets through SharedPreferences.
- Native Kotlin files handle widget rendering, the quick-add dialog, and deep-link navigation.

## Getting Started

### Prerequisites

- Flutter SDK (3.x)
- Firebase CLI
- Dart SDK

### Setup

```bash
git clone https://github.com/MoaazBesher/expensesTracker.git
cd expensesTracker
flutter pub get
```

### Firebase Configuration

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Enable **Google Authentication** and **Cloud Firestore**.
3. Run `flutterfire configure` to generate platform-specific config files.
4. Copy `lib/utils/firebase_config.example.dart` to `lib/utils/firebase_config.dart` and fill in your Firebase project credentials.

### Run

```bash
flutter run
```

## Project Structure

```
android/app/src/main/kotlin/expenses/tracker/
  MainActivity.kt                -- Flutter activity, deep linking, method channels
  QuickAddActivity.kt            -- Native quick-add transaction dialog
  ExpenseQuickTile.kt            -- Android Quick Settings tile
  ExpenseSummaryWidget.kt        -- Finance Summary home widget
  QuickActionsWidget.kt          -- Quick Actions home widget
  RecentTransactionsWidget.kt    -- Recent Activity home widget
  DebtsAlertsWidget.kt           -- Debts & Alerts home widget

android/app/src/main/res/
  layout/                        -- XML layouts for widgets and dialogs
  drawable/                      -- Background shapes and chip styles
  xml/                           -- Widget provider configuration

lib/
  main.dart                      -- App entry, splash, auth, PageView navigation
  screens/
    home_screen.dart             -- Dashboard: balance, accounts, summary, activity, debts
    accounts_screen.dart         -- Account CRUD with add/edit bottom sheets
    transactions_screen.dart     -- Income/expense tabs with search and filters
    reminders_screen.dart        -- Reminder list with add/edit forms
    debts_screen.dart            -- Debt ledger with I Owe / Owed tabs
    login_screen.dart            -- Google sign-in screen
  services/
    auth_service.dart            -- Firebase Authentication wrapper
    firebase_service.dart        -- Firestore CRUD operations (transactions, accounts, debts, reminders)
    widget_service.dart          -- Pushes data to Android home screen widgets
    storage_service.dart         -- Local SQLite for offline support
  models/
    account_model.dart           -- Account data model
  utils/
    app_theme.dart               -- Dark theme colors, text styles, card decorations
    screen_utils.dart            -- Responsive screen utilities (wp, hp, sp, clamp)
    firebase_config.dart         -- Firebase credentials (gitignored)
    firebase_config.example.dart -- Template for Firebase credentials
```

## Screenshots

<!-- Add screenshots here when available -->

## License

MIT License -- see [LICENSE](LICENSE).

---

Developed by [Moaaz Besher](https://github.com/MoaazBesher).
