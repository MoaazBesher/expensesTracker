import 'package:flutter/material.dart';

class AppLocalization {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('en'));
  static bool get isArabic => localeNotifier.value.languageCode == 'ar';

  static void toggleLanguage() {
    if (isArabic) {
      localeNotifier.value = const Locale('en');
    } else {
      localeNotifier.value = const Locale('ar');
    }
  }

  static const Map<String, String> _ar = {
    // Nav
    'Home': 'الرئيسية',
    'Dashboard': 'الرئيسية',
    'Activity': 'النشاط',
    'Transactions': 'الحركات',
    'Sources': 'المصادر',
    'Money Sources': 'مصادر الأموال',
    'Debts': 'الديون',
    'Debts Overview': 'ملخص الديون',
    'Reports': 'التقارير',
    'Monthly Report': 'التقرير الشهري',
    'Alerts': 'التنبيهات',
    'Reminders': 'التذكيرات',
    
    // Header
    'Expenses Tracker': 'المصاريف',
    
    // Home & Common
    'Total Balance': 'إجمالي الرصيد',
    'Income': 'الدخل',
    'Expenses': 'المصروفات',
    'See All': 'عرض الكل',
    'Recent Activity': 'النشاط الأخير',
    'My Accounts': 'حساباتي',
    'Offline': 'غير متصل',
    'Press back again to exit': 'اضغط للرجوع مرة أخرى للخروج',
    'Edit': 'تعديل',
    'Delete': 'حذف',
    'Save': 'حفظ',
    'Add': 'إضافة',
    
    // Quick Add & Categories
    'Quick Add': 'إضافة سريعة',
    'Expense': 'مصروف',
    'Category': 'القسم',
    'Note (optional)': 'ملاحظة (اختياري)',
    'Amount': 'المبلغ',
    'Cancel': 'إلغاء',
    'Add Income': 'إضافة دخل',
    'Add Expense': 'إضافة مصروف',
    'Food': 'طعام',
    'Transport': 'مواصلات',
    'Shopping': 'تسوق',
    'Bills': 'فواتير',
    'Entertainment': 'ترفيه',
    'Health': 'صحة',
    'Education': 'تعليم',
    'Salary': 'راتب',
    'Freelance': 'عمل حر',
    'Gift': 'هدية',
    'Investment': 'استثمار',
    'Other': 'أخرى',
    'General': 'عام',
    'Today': 'اليوم',
    'Yesterday': 'أمس',
    
    // Reports
    'Overview': 'نظرة عامة',
    'Export PDF': 'تصدير PDF',
    'Month Insights': 'تحليل الشهر',
    'No income this month': 'لا يوجد دخل هذا الشهر',
    'No expenses this month': 'لا يوجد مصروفات هذا الشهر',
    
    // Transactions Screen
    'All Types': 'كل الحركات',
    'Apply Filters': 'تطبيق الفلتر',
    'Reset': 'إعادة ضبط',
    'Filters': 'تصفية',
    'Search transactions...': 'ابحث في الحركات...',
    'No transactions found.': 'لا توجد حركات.',
    'Add Transaction': 'إضافة حركة',
    'Add Note (Optional)': 'أضف ملاحظة (اختياري)',
    'New Entry': 'عملية جديدة',
    'Save Changes': 'حفظ التغييرات',
    'Confirm': 'تأكيد',
    'All': 'الكل',
    'All categories': 'كل الأقسام',
    
    // Debts
    'Add Debt': 'إضافة دين',
    'New Debt': 'دين جديد',
    'Owes you': 'عليه دين لك',
    'They owe you': 'عليهم دين لك',
    'You owe them': 'عليك دين لهم',
    'Owed to Me': 'لي ديون',
    'I Owe': 'عليّ',
    'Owed To Me': 'لي',
    'Person/Entity Name': 'اسم الشخص/الجهة',
    'Status': 'الحالة',
    'Pending': 'معلق',
    'Paid': 'تم الدفع',
    'No debts recorded yet.': 'لا توجد ديون مسجلة.',
    'Settle Debt': 'تسديد الدين',
    
    // Accounts
    'Account Name': 'اسم الحساب',
    'Initial Balance': 'الرصيد الافتتاحي',
    'Add Account': 'إضافة حساب',
    'Total Assets': 'إجمالي الأصول',
    'Edit Account': 'تعديل الحساب',
    'Delete Account': 'حذف الحساب',
    
    // Reminders
    'Add Alert': 'إضافة تنبيه',
    'Title': 'العنوان',
    'Due Date': 'تاريخ الاستحقاق',
    'Amount (Optional)': 'المبلغ (اختياري)',
    'No alerts set.': 'لا توجد تنبيهات.',
    'Upcoming': 'قادم',
    'Overdue': 'متأخر',
    'No alerts': 'لا توجد تنبيهات',
    'New Alert': 'تنبيه جديد',
    'Create Alert': 'إنشاء تنبيه',
    'Delete Alert?': 'حذف التنبيه؟',
    'Edit Alert': 'تعديل التنبيه',
    'Date & Time': 'التاريخ والوقت',
    'Notes': 'ملاحظات',
    'Actions': 'إجراءات',
    'Select alerts': 'اختر التنبيهات',
    'selected': 'تم اختيارهم',
    'Upcoming Alert': 'تنبيه قادم',
    'Pending upload': 'في انتظار الرفع',
    'No accounts added yet': 'لا توجد حسابات مضافة بعد',
    'No recent transactions': 'لا توجد حركات أخيرة',
    'Welcome': 'أهلاً بك',
    'Track your finances.': 'تتبع أمورك المالية.',
    'Continue with Google': 'المتابعة باستخدام Google',
    'Sign in failed': 'فشل تسجيل الدخول',
    'Top expense': 'أكثر قسم صرفاً',
    'Great job! You saved': 'عمل رائع! لقد وفرت',
    'Careful, you spent': 'انتبه، لقد صرفت',
    'more than you earned': 'أكثر مما جنيت',
    'You broke even this month': 'لقد تساوت مصروفاتك مع دخلك هذا الشهر',
    'transactions': 'عمليات',
    'Account': 'الحساب',
    'Summary': 'ملخص',
    'Person': 'الشخص',
    'Your Accounts': 'حساباتك',
    'source': 'مصدر',
    'sources': 'مصادر',
    'Name': 'الاسم',
    'Balance': 'الرصيد',
    'Type': 'النوع',
    'Cash': 'كاش',
    'Bank': 'بنك',
    'Visa': 'فيزا',
    'Savings': 'مدخرات',
  };

  static String translate(String key) {
    if (isArabic) {
      return _ar[key] ?? key;
    }
    return key;
  }
}

extension StringLocalization on String {
  String get tr => AppLocalization.translate(this);
}
