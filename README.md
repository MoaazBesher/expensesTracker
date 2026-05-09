# Expenses Tracker

A personal finance management application built with Flutter and Firebase. Track income, expenses, accounts, debts, and financial reminders with offline support.

## Features

- **Account Management** -- Track multiple financial sources (cash, credit cards, savings) with real-time net worth calculation.
- **Income & Expense Logging** -- Categorize and record transactions with an income/expense split view.
- **Debt Ledger** -- Separate tracking for money owed and money due, with automatic net balance calculation.
- **Reminders** -- Date-driven notification system for upcoming bills and financial obligations.
- **Offline Support** -- Local caching ensures full functionality without internet; data syncs to Firebase when connectivity resumes.
- **Responsive UI** -- Scales across phone sizes using a utility-based responsive system.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Authentication, Firestore, Realtime Database)
- **State Management**: StatefulWidget lifecycle + Stream-based reactivity

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
2. Enable Google Authentication and Cloud Firestore.
3. Run `flutterfire configure` to generate platform-specific configs.
4. Copy `lib/utils/firebase_config.example.dart` to `lib/utils/firebase_config.dart` and fill in your Firebase project credentials.

### Run

```bash
flutter run
```

## Project Structure

```
lib/
  main.dart                    -- App entry point, navigation, PageView swiping
  screens/
    home_screen.dart           -- Dashboard with balance, accounts, recent activity
    accounts_screen.dart       -- Money sources CRUD
    transactions_screen.dart   -- Income/expense tabs
    reminders_screen.dart      -- Financial reminders
    debts_screen.dart          -- Debt ledger
    login_screen.dart          -- Google sign-in
    monthly_bills_screen.dart  -- Monthly report view
  services/
    auth_service.dart          -- Firebase Authentication wrapper
    firebase_service.dart      -- Firestore CRUD operations
  utils/
    app_theme.dart             -- Dark theme palette and card styles
    screen_utils.dart          -- Responsive dimension helper
    firebase_config.dart       -- Firebase credentials (gitignored)
    firebase_config.example.dart -- Template for credentials
```

## License

MIT License -- see [LICENSE](LICENSE).

---

Developed by [Moaaz Besher](https://github.com/MoaazBesher).
