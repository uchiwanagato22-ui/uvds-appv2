import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const String uvdsPaymentNumber = '32652300';
const double usdToMruRate = 40.0;
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
  final usdStr = usd is int || usd == usd.roundToDouble() ? '${usd.toInt()}' : usd.toStringAsFixed(2);
  return '\$$usdStr ≈ ${formatMru(mruFromUsd(usd))} MRU';
}

class DonationService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String tierForTotal(double total) {
    if (total >= 50) return 'gold';
    if (total >= 20) return 'silver';
    if (total >= 10) return 'bronze';
    if (total >= 5)  return 'soutien';
    return 'none';
  }

  static Future<String?> requestDonation({
    required double amount,
    String? message,
    String? reference,
    required String method,
    required String donorName,
    required String senderPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur non connecté';

    try {
      await _db.collection('donations').add({
        'amount': amount,
        'message': message ?? '',
        'reference': reference ?? '',
        'method': method,
        'senderPhone': senderPhone,
        'donorName': donorName,
        'donorId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> approveDonation(String donationId, String donorId, double amount) async {
    final batch = _db.batch();

    final donationRef = _db.collection('donations').doc(donationId);
    batch.update(donationRef, {'status': 'completed'});

    final userRef = _db.collection('users').doc(donorId);
    final userSnap = await userRef.get();
    final userData = userSnap.data() ?? {};

    final previousTotal = (userData['totalDonated'] as num?)?.toDouble() ?? 0.0;
    final newTotal = previousTotal + amount;
    final newTier = tierForTotal(newTotal);

    final updates = <String, dynamic>{
      'totalDonated': newTotal,
      'donationTier': newTier,
      'lastDonationAt': FieldValue.serverTimestamp(),
    };
    if (newTier == 'gold') updates['role'] = 'admin';

    batch.set(userRef, updates, SetOptions(merge: true));

    final notifRef = _db.collection('notifications').doc();
    batch.set(notifRef, {
      'uid': donorId,
      'message': '🎉 Don approuvé ! Merci pour ton soutien (${usdWithMru(amount)}). Grade : ${newTier.toUpperCase()}',
      'read': false,
      'time': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
