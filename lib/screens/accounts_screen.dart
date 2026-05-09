import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';
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
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) return _buildEmptyState();
          return ListView.builder(
            padding: EdgeInsets.all(S.sectionPadding),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) => _buildAccountTile(snapshot.data![index]),
          );
        },
      ),
          Positioned(
            right: 24, bottom: 24,
            child: FloatingActionButton(
              onPressed: _showAddAccountSheet,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    final isVisa = account.type.toLowerCase().contains('visa');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(radius: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(isVisa ? Icons.credit_card : Icons.account_balance_wallet, color: AppTheme.primary, size: 20),
        ),
        title: Text(account.name, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(account.type, style: TextStyle(color: AppTheme.textDim, fontSize: S.fontSmall)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${account.balance.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 15)),
            if (account.isDefault) const SizedBox(height: 2),
            if (account.isDefault) Text('Primary', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w600)),
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
          Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppTheme.textDim.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No accounts yet', style: TextStyle(color: AppTheme.textDim, fontSize: S.fontBody)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _showAddAccountSheet(),
            child: const Text('Add Account'),
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
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Money Source', style: TextStyle(color: AppTheme.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. My Visa'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Balance', prefixText: '\$ '),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Type'),
                dropdownColor: AppTheme.surfaceLight,
                style: const TextStyle(color: AppTheme.textMain),
                items: ['Cash', 'Bank', 'Visa', 'Savings', 'Other']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => selectedType = val!),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final balance = double.tryParse(balanceController.text) ?? 0.0;
                    if (name.isNotEmpty) {
                      await _firebaseService.addAccount(name: name, initialBalance: balance, type: selectedType);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Create Account'),
                ),
              ),
            ],
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
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star_border, color: AppTheme.secondary),
              title: const Text('Set as Default'),
              onTap: () async {
                await _firebaseService.setAccountAsDefault(account.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.accent),
              title: const Text('Delete Account', style: TextStyle(color: AppTheme.accent)),
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
