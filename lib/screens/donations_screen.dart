import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/donation_service.dart';

final _db = FirebaseFirestore.instance;

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  double _amount = 10;
  String _method = 'bankily';
  final _refCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String _successTier = 'none';
  bool _becameAdmin = false;
  String? _error;

  @override
  void dispose() {
    _refCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _copyNumber() async {
    await Clipboard.setData(
        const ClipboardData(text: uvdsPaymentNumber));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Numéro copié : $uvdsPaymentNumber'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await DonationService.confirmDonation(
      amount: _amount,
      method: _method,
      reference: _refCtrl.text.trim(),
      message: _msgCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.error != null) {
        _error = result.error;
      } else {
        _success = true;
        _successTier = result.tier;
        _becameAdmin = result.becameAdmin;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        appBar: AppBar(title: const Text('Merci !')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo_uvds.png', height: 100),
              const SizedBox(height: 24),
              Text(
                'Don de \$${_amount.toStringAsFixed(0)} enregistré',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _becameAdmin
                    ? 'Tu as maintenant accès au Panel Admin.'
                    : 'Niveau : ${DonationService.tierLabel(_successTier)}',
                style: const TextStyle(color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Soutenir UVDS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)),
              ),

            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/logo_uvds.png',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            const Text('Choisis ton palier',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            ...donationTierInfos.map((t) {
              final selected = _amount == t.amount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _amount = t.amount),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(t.perks,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textGrey)),
                            ],
                          ),
                        ),
                        Text('\$${t.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
            const Text('Moyen de paiement',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PayMethodChip(
                    label: 'Bankily',
                    icon: Icons.account_balance_wallet,
                    selected: _method == 'bankily',
                    onTap: () => setState(() => _method = 'bankily'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PayMethodChip(
                    label: 'Masrivi',
                    icon: Icons.phone_android,
                    selected: _method == 'masrivi',
                    onTap: () => setState(() => _method = 'masrivi'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF2E8B57)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Envoie le montant à ce numéro',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    uvdsPaymentNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _method == 'bankily' ? 'via Bankily' : 'via Masrivi',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: _copyNumber,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copier le numéro'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            TextField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Référence de transaction (optionnel)',
                hintText: 'Ex: derniers chiffres du reçu',
                prefixIcon: Icon(Icons.receipt_long, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _msgCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message (optionnel)',
                hintText: 'Motivation, projet soutenu...',
              ),
            ),

            const SizedBox(height: 24),
            const Text('Derniers dons',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('donations')
                  .orderBy('createdAt', descending: true)
                  .limit(8)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const SizedBox();
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Text('Sois le premier à soutenir UVDS !',
                      style: TextStyle(color: AppColors.textGrey));
                }
                return Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final method = d['method'] ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.favorite,
                          color: AppColors.primary, size: 20),
                      title: Text(d['donorName'] ?? 'Anonyme',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        '${method == 'bankily' ? 'Bankily' : method == 'masrivi' ? 'Masrivi' : method}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Text(
                        '\$${(d['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_loading
                  ? 'Enregistrement...'
                  : 'J\'ai payé — confirmer \$${_amount.toStringAsFixed(0)}'),
              onPressed: _loading ? null : _confirmPayment,
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Vérifie que le montant envoyé correspond au palier choisi.',
                style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppColors.primary : AppColors.textGrey),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textDark,
                )),
          ],
        ),
      ),
    );
  }
}
