import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Numéro mobile money UVDS (Bankily / Masrivi).
const String uvdsPaymentNumber = '32652300';

/// Taux indicatif affiché (1 USD ≈ X MRU). Ajuster selon le marché.
const double usdToMruRate = 40.0;

/// Montants de don et avantages associés (USD).
const List<double> donationTiers = [5, 10, 20, 50];

int mruFromUsd(num usd) => (usd * usdToMruRate).round();

String formatMru(int mru) {
  final s = mru.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

String usdWithMru(num usd) {
  final usdStr = usd is int || usd == usd.roundToDouble()
      ? '${usd.toInt()}'
      : usd.toStringAsFixed(2);
  return '\$$usdStr ≈ ${formatMru(mruFromUsd(usd))} MRU';
}

String mruPaymentLabel(num usd) =>
    '${formatMru(mruFromUsd(usd))} MRU';

class DonationTierInfo {
  final double amount;
  final String id;
  final String title;
  final String perks;

  DonationTierInfo({
    required this.amount,
    required this.id,
    required this.title,
    required this.perks,
  });
}

final List<DonationTierInfo> donationTierInfos = [
  DonationTierInfo(
    amount: 5,
    id: 'supporter',
    title: 'Soutien — ${usdWithMru(5)}',
    perks: 'Badge Supporter sur ton profil',
  ),
  DonationTierInfo(
    amount: 10,
    id: 'bronze',
    title: 'Bronze — ${usdWithMru(10)}',
    perks: 'Badge Bronze + statistiques communauté',
  ),
  DonationTierInfo(
    amount: 20,
    id: 'silver',
    title: 'Silver — ${usdWithMru(20)}',
    perks: 'Annuaire membres + publications mises en avant',
  ),
  DonationTierInfo(
    amount: 50,
    id: 'gold',
    title: 'Gold — ${usdWithMru(50)}',
    perks: 'Accès Panel Admin complet',
  ),
];

class DonationService {
  static final _db = FirebaseFirestore.instance;

  static String tierForTotal(double total) {
    if (total >= 50) return 'gold';
    if (total >= 20) return 'silver';
    if (total >= 10) return 'bronze';
    if (total >= 5) return 'supporter';
    return 'none';
  }

  static String tierLabel(String tier) {
    switch (tier) {
      case 'gold':
        return 'Gold Admin';
      case 'silver':
        return 'Silver';
      case 'bronze':
        return 'Bronze';
      case 'supporter':
        return 'Supporter';
      default:
        return 'Membre';
    }
  }

  static bool isAdmin(Map<String, dynamic>? user) =>
      (user?['role'] ?? '') == 'admin';

  /// Palier affiché (Soutien, Bronze…) → clé Firestore (supporter, bronze…).
  static String donationTierKeyFromDisplay(String? displayTier) {
    switch (displayTier) {
      case 'Gold':
        return 'gold';
      case 'Silver':
        return 'silver';
      case 'Bronze':
        return 'bronze';
      case 'Soutien':
        return 'supporter';
      default:
        return 'none';
    }
  }

  static bool hasGoldTier(Map<String, dynamic>? user) {
    final tier = (user?['tier'] ?? user?['donationTier'] ?? '').toString();
    return tier == 'Gold' || tier.toLowerCase() == 'gold';
  }

  static bool canAccessAdmin(Map<String, dynamic>? user) =>
      isAdmin(user) || hasGoldTier(user);

  static bool canAccessStats(Map<String, dynamic>? user) {
    final tier = user?['donationTier'] ?? 'none';
    return isAdmin(user) ||
        tier == 'bronze' ||
        tier == 'silver' ||
        tier == 'gold';
  }

  static bool canAccessMembers(Map<String, dynamic>? user) {
    final tier = user?['donationTier'] ?? 'none';
    return isAdmin(user) || tier == 'silver' || tier == 'gold';
  }

  static bool canFeaturePosts(Map<String, dynamic>? user) {
    final tier = user?['donationTier'] ?? 'none';
    return isAdmin(user) || tier == 'silver' || tier == 'gold';
  }

  /// Enregistre le don et applique les paliers (cumul des dons confirmés).
  static Future<({String? error, String tier, bool becameAdmin})> confirmDonation({
    required double amount,
    required String method,
    String? reference,
    String? message,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return (error: 'Connecte-toi pour faire un don.', tier: 'none', becameAdmin: false);
    }

    if (!donationTiers.contains(amount)) {
      return (
        error: 'Choisis 5, 10, 20 ou 50\$ uniquement.',
        tier: 'none',
        becameAdmin: false,
      );
    }

    try {
      final donorName = user.displayName ?? 'Membre';
      final userRef = _db.collection('users').doc(user.uid);
      final userSnap = await userRef.get();
      final userData = userSnap.data() ?? {};
      final previousTotal =
          (userData['totalDonated'] as num?)?.toDouble() ?? 0;
      final newTotal = previousTotal + amount;
      final newTier = tierForTotal(newTotal);

      await _db.collection('donations').add({
        'amount': amount,
        'message': message ?? '',
        'reference': reference ?? '',
        'method': method,
        'donorName': userData['name'] ?? donorName,
        'donorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });

      final updates = <String, dynamic>{
        'totalDonated': newTotal,
        'donationTier': newTier,
        'lastDonationAt': FieldValue.serverTimestamp(),
      };
      final becameAdmin = newTier == 'gold';
      if (becameAdmin) updates['role'] = 'admin';

      await userRef.set(updates, SetOptions(merge: true));

      return (error: null, tier: newTier, becameAdmin: becameAdmin);
    } catch (e) {
      return (
        error: 'Erreur lors de l\'enregistrement : $e',
        tier: 'none',
        becameAdmin: false,
      );
    }
  }

  static Future<double> totalDonationsAllTime() async {
    final snap = await _db
        .collection('donations')
        .where('status', isEqualTo: 'completed')
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      total += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }
}
