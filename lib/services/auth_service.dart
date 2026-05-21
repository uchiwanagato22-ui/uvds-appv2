import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth      = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authChanges => _auth.authStateChanges();

  static Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      await cred.user!.updateDisplayName(name);
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid':          cred.user!.uid,
        'name':         name,
        'email':        email,
        'role':         'membre',
        'photoUrl':     '',
        'bio':          '',
        'totalDonated': 0.0,
        'donationTier': 'none',
        'online':       true,
        'createdAt':    FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use': return 'Cet email est déjà utilisé.';
        case 'weak-password':        return 'Mot de passe trop court (min 6).';
        case 'invalid-email':        return 'Email invalide.';
        default:                     return 'Erreur : ${e.message}';
      }
    } catch (_) {
      return 'Erreur inattendue.';
    }
  }

  static Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      await _firestore
          .collection('users')
          .doc(cred.user!.uid)
          .update({'online': true});
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':    return 'Aucun compte avec cet email.';
        case 'wrong-password':    return 'Mot de passe incorrect.';
        case 'invalid-email':     return 'Email invalide.';
        case 'too-many-requests': return 'Trop de tentatives. Réessaie plus tard.';
        default:                  return 'Erreur de connexion.';
      }
    } catch (_) {
      return 'Erreur inattendue.';
    }
  }

  static Future<void> logout() async {
    if (_auth.currentUser != null) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'online': false});
    }
    await _auth.signOut();
  }
}
