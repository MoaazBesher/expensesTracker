import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/account_model.dart';
import '../utils/app_theme.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Money Sources'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primary),
            onPressed: () => _showAddAccountSheet(),
          ),
        ],
      ),
      body: StreamBuilder<List<AccountModel>>(
        stream: _firebaseService.getAccounts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final accounts = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: accounts.length,
            itemBuilder: (context, index) => _buildAccountTile(accounts[index]),
          );
        },
      ),
    );
  }

  Widget _buildAccountTile(AccountModel account) {
    final isVisa = account.type.toLowerCase().contains('visa');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.glassDecoration(opacity: 0.05),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(isVisa ? Icons.credit_card : Icons.account_balance_wallet, color: AppTheme.primary),
        ),
        title: Text(account.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(account.type, style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${account.balance.toStringAsFixed(2)}', 
                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(account.isDefault ? 'Primary' : '', style: const TextStyle(color: AppTheme.secondary, fontSize: 10, fontWeight: FontWeight.bold)),
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
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppTheme.textDim.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No accounts found', style: TextStyle(color: AppTheme.textDim, fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddAccountSheet(),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Add Your First Account'),
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
        builder: (context, setSheetState) => Container(
          decoration: AppTheme.glassDecoration(color: AppTheme.surfaceLight, opacity: 1),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Money Source', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Account Name',
                  hintText: 'e.g. My Visa, Wallet, Bank',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Initial Balance',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: 'Account Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                dropdownColor: AppTheme.surfaceLight,
                style: const TextStyle(color: Colors.white),
                items: ['Cash', 'Bank', 'Visa', 'Savings', 'Other']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setSheetState(() => selectedType = val!),
              ),
              const SizedBox(height: 32),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
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
        decoration: AppTheme.glassDecoration(color: AppTheme.surfaceLight, opacity: 1),
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
                // Should add confirmation dialog
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
