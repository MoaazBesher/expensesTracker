# Expenses Tracker

A personal finance management application built with Flutter and Firebase. Track income, expenses, accounts, debts, and financial reminders with offline support and a dark GitHub-style theme.

## Features

- **Dashboard** -- Real-time balance overview, monthly income/expense summary, recent transactions, and debt/alert stats.
- **Account Management** -- Track multiple financial sources (cash, credit cards, savings) with CRUD operations.
- **Income & Expense Logging** -- Categorize and record transactions with searchable income/expense split view.
- **Debt Ledger** -- Separate tracking for money owed and money due, with automatic net balance calculation.
- **Reminders** -- Date-driven notification system for upcoming bills and financial obligations.
- **Swipe Navigation** -- Navigate between sections by swiping left/right with a synchronized bottom navigation bar.
- **Offline Support** -- Local caching ensures full functionality without internet; data syncs to Firebase when connectivity resumes.
- **Quick Add Dialog** -- Native Android dialog for quickly adding transactions from anywhere.
- **Home Screen Widgets** -- 4 Android widgets (Summary, Quick Actions, Recent Activity, Debts & Alerts) in compact 3x2 layout.

## Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: Firebase (Authentication, Firestore, Realtime Database)
- **State Management**: StatefulWidget lifecycle + Stream-based reactivity
- **Native Android**: Kotlin (widgets, quick add, deep linking)

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

## Home Screen Widgets

The app includes 4 Android home screen widgets (3x2, 200dp x 110dp):

| Widget | Content |
|---|---|
| **Finance Summary** | Total balance with account list |
| **Quick Actions** | Income, Expense, Alert, Debt shortcuts |
| **Recent Activity** | Last 3 transactions |
| **Debts & Alerts** | Owe/Owed totals with nearest 2 alerts |

Widgets update automatically via `WidgetService` when data changes.

## Project Structure

```
android/
  app/src/main/
    kotlin/expenses/tracker/
      MainActivity.kt           -- Flutter activity with deep linking
      QuickAddActivity.kt        -- Native quick-add dialog
      ExpenseSummaryWidget.kt    -- Summary home widget
      QuickActionsWidget.kt      -- Quick actions home widget
      RecentTransactionsWidget.kt -- Recent activity home widget
      DebtsAlertsWidget.kt       -- Debts & alerts home widget
      ExpenseQuickTile.kt        -- Quick settings tile
    res/
      layout/                    -- Widget & dialog layouts
      drawable/                  -- Custom backgrounds & chips
      xml/                       -- Widget provider info

lib/
  main.dart                      -- App entry point, navigation, PageView swiping
  screens/
    home_screen.dart             -- Dashboard with balance, accounts, recent activity
    accounts_screen.dart         -- Money sources CRUD
    transactions_screen.dart     -- Income/expense tabs
    reminders_screen.dart        -- Financial reminders
    debts_screen.dart            -- Debt ledger
    login_screen.dart            -- Google sign-in
  services/
    auth_service.dart            -- Firebase Authentication wrapper
    firebase_service.dart        -- Firestore CRUD operations
    widget_service.dart          -- Home screen widget data push
    storage_service.dart         -- Local SQLite storage
  models/
    account_model.dart           -- Account data model
  utils/
    app_theme.dart               -- Dark theme palette and card styles
    screen_utils.dart            -- Responsive dimension helper
    firebase_config.dart         -- Firebase credentials (gitignored)
    firebase_config.example.dart -- Template for credentials
```

## License

MIT License -- see [LICENSE](LICENSE).

---

Developed by [Moaaz Besher](https://github.com/MoaazBesher).
