import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_localization.dart';
import '../utils/screen_utils.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    S.init(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          StreamBuilder<List<AccountModel>>(
            stream: _firebaseService.getAccounts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();

              final accounts = snapshot.data!;
              final totalBalance = accounts.fold(0.0, (s, a) => s + a.balance);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // ── Total balance banner ──────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.14),
                              AppTheme.primary.withValues(alpha: 0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.22)),
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Across All Sources'.tr,
                                    style: TextStyle(color: AppTheme.textDim, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${totalBalance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppTheme.textMain,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primary, size: 26),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Section header ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Accounts'.tr,
                            style: const TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${accounts.length} ${accounts.length == 1 ? 'source'.tr : 'sources'.tr}',
                            style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Accounts list ─────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildAccountTile(accounts[i]),
                        childCount: accounts.length,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── FAB ────────────────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: _showAddAccountSheet,
              backgroundColor: AppTheme.primary,
              elevation: 4,
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    final isVisa = account.type.toLowerCase().contains('visa');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.cardDecoration(radius: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isVisa ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          account.name,
          style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            account.type.tr,
            style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${account.balance.toStringAsFixed(2)}',
              style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (account.isDefault) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Primary'.tr, style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        onLongPress: () => _showAccountOptions(account),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_outlined, size: 40, color: AppTheme.textDim.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('No accounts yet'.tr, style: const TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Add a money source to get started'.tr, style: const TextStyle(color: AppTheme.textDim, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddAccountSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add Account'.tr),
          ),
        ],
      ),
    );
  }

  void _showAddAccountSheet() {
    final nameController = TextEditingController();
    final balanceController = TextEditingController();
    String selectedType = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Add Money Source'.tr,
                    style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'.tr, hintText: 'e.g. My Visa'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Balance'.tr, prefixText: '\$ '),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(labelText: 'Type'.tr),
                  dropdownColor: AppTheme.surfaceLight,
                  style: const TextStyle(color: AppTheme.textMain),
                  items: ['Cash', 'Bank', 'Visa', 'Savings', 'Other']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.tr))).toList(),
                  onChanged: (val) => setSheetState(() => selectedType = val!),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final balance = double.tryParse(balanceController.text) ?? 0.0;
                      if (name.isNotEmpty) {
                        await _firebaseService.addAccount(name: name, initialBalance: balance, type: selectedType);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: Text('Create Account'.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAccountOptions(AccountModel account) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
            Text(account.name, style: const TextStyle(color: AppTheme.textMain, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.surfaceLight,
              leading: const Icon(Icons.star_rounded, color: AppTheme.secondary, size: 22),
              title: Text('Set as Primary'.tr, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500)),
              onTap: () async {
                await _firebaseService.setAccountAsDefault(account.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: AppTheme.accent.withValues(alpha: 0.08),
              leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accent, size: 22),
              title: Text('Delete Account'.tr, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w500)),
              onTap: () async {
                await _firebaseService.deleteAccount(account.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
