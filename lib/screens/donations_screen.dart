import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/donation_service.dart';

final _db = FirebaseFirestore.instance;

Future<String> getRealName() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return 'Membre';
  try {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['name'] ??
        FirebaseAuth.instance.currentUser?.displayName ??
        'Membre';
  } catch (_) {
    return FirebaseAuth.instance.currentUser?.displayName ?? 'Membre';
  }
}

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  // ── Paliers ────────────────────────
  final List<Map<String, dynamic>> _tiers = [
    {
      'name':   'Soutien',
      'amount': 5,
      'desc':   'Badge Supporter sur ton profil',
      'badge':  '🤝',
    },
    {
      'name':   'Bronze',
      'amount': 10,
      'desc':   'Badge Bronze + statistiques communauté',
      'badge':  '🥉',
    },
    {
      'name':   'Silver',
      'amount': 20,
      'desc':   'Annuaire membres + publications mises en avant',
      'badge':  '🥈',
    },
    {
      'name':   'Gold',
      'amount': 50,
      'desc':   'Accès Panel Admin complet',
      'badge':  '🥇',
    },
  ];

  int    _selectedTier  = 1;
  String _paymentMethod = 'Bankily';
  final  _refCtrl       = TextEditingController();
  final  _msgCtrl       = TextEditingController();
  bool   _loading       = false;
  bool   _confirmed     = false;

  // ⚠️ CHANGE CES NUMÉROS PAR CEUX DE TON PÈRE
  static const String _bankilyNumber  = '32652300';
  static const String _masriviNumber  = '32652300';

  String get _currentNumber =>
      _paymentMethod == 'Bankily' ? _bankilyNumber : _masriviNumber;

  @override
  void dispose() {
    _refCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  // ── Confirmer le paiement ──────────
  Future<void> _confirmPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecte-toi pour faire un don.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_refCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indique la référence de ton paiement Bankily/Masrivi.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final tier     = _tiers[_selectedTier];
      final realName = await getRealName();

      // 1. Enregistre dans Firestore
      final donRef = await _db.collection('donations').add({
        'donorId':       user.uid,
        'donorName':     realName,
        'amount':        tier['amount'],
        'amountMru':     mruFromUsd(tier['amount'] as num),
        'tier':          tier['name'],
        'badge':         tier['badge'],
        'paymentMethod': _paymentMethod,
        'reference':     _refCtrl.text.trim(),
        'message':       _msgCtrl.text.trim(),
        'status':        'pending',
        'createdAt':     FieldValue.serverTimestamp(),
      });

      // 2. Badge en attente sur le profil
      await _db.collection('users').doc(user.uid).set({
          'pendingBadge':  tier['badge'],
          'pendingTier':   tier['name'],
          'pendingDonRef': donRef.id,
        }, SetOptions(merge: true));

      // 3. Notifie les admins
      final admins = await _db.collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in admins.docs) {
        await _db.collection('notifications').add({
          'uid':     admin.id,
          'message': '💰 $realName a fait un don ${tier['badge']} '
              'de ${usdWithMru(tier['amount'] as num)} via $_paymentMethod — Ref: ${_refCtrl.text.trim()}',
          'read':    false,
          'time':    FieldValue.serverTimestamp(),
        });
      }

      if (mounted) setState(() { _loading = false; _confirmed = true; });

    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── UI ────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Écran succès
    if (_confirmed) {
      final tier = _tiers[_selectedTier];
      return Scaffold(
        appBar: AppBar(title: const Text('Don confirmé ✅')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(tier['badge'] as String,
                  style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 20),
              Text('Merci pour ton don de ${usdWithMru(tier['amount'] as num)} ! 🙏',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              const Text(
                'L\'admin va valider ton paiement.\nTon badge apparaîtra bientôt sur ton profil.',
                style: TextStyle(color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
            ]),
          ),
        ),
      );
    }

    final tier = _tiers[_selectedTier];

    return Scaffold(
      appBar: AppBar(title: const Text('Soutenir UVDS 💚')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Bannière
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2E8B57)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism, size: 48, color: Colors.white),
                SizedBox(height: 8),
                Text('Soutenir UVDS',
                    style: TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            )),
          ),
          const SizedBox(height: 24),

          // ── Paliers ─────────────────
          const Text('Choisis ton palier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'Paiement Bankily/Masrivi en MRU — taux indicatif : 1 USD ≈ ${usdToMruRate.toInt()} MRU',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),

          ..._tiers.asMap().entries.map((entry) {
            final i   = entry.key;
            final t   = entry.value;
            final sel = _selectedTier == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedTier = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border,
                    width: sel ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Radio<int>(
                    value: i,
                    groupValue: _selectedTier,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _selectedTier = v!),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t['badge']} ${t['name']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(usdWithMru(t['amount'] as num),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(t['desc'] as String,
                          style: const TextStyle(
                              color: AppColors.textGrey, fontSize: 13)),
                    ],
                  )),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(mruPaymentLabel(t['amount'] as num),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                      Text('\$${t['amount']}',
                          style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 12)),
                    ],
                  ),
                ]),
              ),
            );
          }),

          const SizedBox(height: 20),

          // ── Méthode paiement ────────
          const Text('Moyen de paiement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Row(children: ['Bankily', 'Masrivi'].map((method) {
            final sel  = _paymentMethod == method;
            final last = method == 'Masrivi';
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _paymentMethod = method),
                child: Container(
                  margin: EdgeInsets.only(left: last ? 8 : 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.border,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(children: [
                    Icon(
                      method == 'Bankily'
                          ? Icons.account_balance_wallet
                          : Icons.phone_android,
                      color: sel ? AppColors.primary : AppColors.textGrey,
                      size: 30,
                    ),
                    const SizedBox(height: 6),
                    Text(method,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: sel ? AppColors.primary : AppColors.textDark)),
                  ]),
                ),
              ),
            );
          }).toList()),

          const SizedBox(height: 20),

          // ── Numéro à copier ─────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2E8B57)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Text('Envoie ce montant à ce numéro',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
              const SizedBox(height: 10),
              Text(mruPaymentLabel(tier['amount'] as num),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(usdWithMru(tier['amount'] as num),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14)),
              const SizedBox(height: 12),
              Text(_currentNumber,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3)),
              const SizedBox(height: 4),
              Text('via $_paymentMethod',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                    label: const Text('Numéro',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _currentNumber));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Numéro copié ! 📋'),
                          backgroundColor: AppColors.primary,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.payments, color: Colors.white, size: 16),
                    label: Text(
                      mruPaymentLabel(tier['amount'] as num),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () {
                      final mru = mruFromUsd(tier['amount'] as num);
                      Clipboard.setData(ClipboardData(text: '$mru'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Montant ${mruPaymentLabel(tier['amount'] as num)} copié ! 📋'),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Référence ───────────────
          TextField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              hintText: 'Référence de transaction Bankily/Masrivi',
              prefixIcon: Icon(Icons.receipt_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // ── Message ─────────────────
          TextField(
            controller: _msgCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Message (optionnel)',
            ),
          ),

          const SizedBox(height: 20),

          // ── Derniers dons ───────────
          const Text('Derniers dons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('donations')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sois le premier à donner ! 💚',
                      style: TextStyle(color: AppColors.textGrey)),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(d['badge'] ?? '❤️',
                        style: const TextStyle(fontSize: 26)),
                    title: Text(d['donorName'] ?? 'Anonyme',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(d['paymentMethod'] ?? ''),
                    trailing: Text(
                        d['amountMru'] != null
                            ? '${formatMru((d['amountMru'] as num).toInt())} MRU'
                            : usdWithMru((d['amount'] as num?) ?? 0),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Bouton confirmer CORRIGÉ ─
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_loading
                  ? 'Confirmation en cours...'
                  : 'J\'ai payé — ${mruPaymentLabel(tier['amount'] as num)}'),
              // ← BOUTON CORRIGÉ — appelle _confirmPayment
              onPressed: _loading ? null : _confirmPayment,
            ),
          ),

          const SizedBox(height: 8),
          Center(
            child: Text(
              'Envoie exactement ${mruPaymentLabel(tier['amount'] as num)} (${usdWithMru(tier['amount'] as num)}) sur Bankily ou Masrivi.',
              style: const TextStyle(fontSize: 11, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
