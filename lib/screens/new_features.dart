import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

final _featDb = FirebaseFirestore.instance;

// ═══════════════════════════════════════
// ❤️ RÉACTIONS AUX POSTS
// ═══════════════════════════════════════
// Remplace le bouton like dans PostCard par ReactionsBar

class ReactionsBar extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final Map<String, dynamic> data;
  const ReactionsBar({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.data,
  });
  @override
  State<ReactionsBar> createState() => _ReactionsBarState();
}

class _ReactionsBarState extends State<ReactionsBar> {
  bool _showEmojis = false;

  static const Map<String, String> _emojis = {
    '❤️': 'heart',
    '👍': 'like',
    '😂': 'haha',
    '😮': 'wow',
    '😢': 'sad',
    '🙏': 'pray',
  };

  Future<void> _react(String emoji) async {
    final uid  = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final reactions = Map<String, dynamic>.from(widget.data['reactions'] ?? {});

    // Toggle reaction
    if (reactions[uid] == emoji) {
      reactions.remove(uid);
    } else {
      reactions[uid] = emoji;
    }

    await _featDb.collection('posts').doc(widget.postId).update({
      'reactions': reactions,
    });

    // Notif si c'est pas ton post
    if (widget.postAuthorId != uid && reactions.containsKey(uid)) {
      final name = FirebaseAuth.instance.currentUser?.displayName ?? 'Quelqu\'un';
      await _featDb.collection('notifications').add({
        'uid':     widget.postAuthorId,
        'message': '$name a réagi $emoji à ton post',
        'read':    false,
        'time':    FieldValue.serverTimestamp(),
      });
    }

    setState(() => _showEmojis = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid       = FirebaseAuth.instance.currentUser?.uid;
    final reactions = Map<String, dynamic>.from(widget.data['reactions'] ?? {});
    final myReaction = reactions[uid] as String?;

    // Compter les réactions
    final Map<String, int> counts = {};
    for (final r in reactions.values) {
      counts[r as String] = (counts[r] ?? 0) + 1;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Afficher les réactions existantes
      if (counts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            children: counts.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text('${e.key} ${e.value}',
                  style: const TextStyle(fontSize: 13)),
            )).toList(),
          ),
        ),

      // Bouton réagir
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(children: [
          // Picker emojis
          if (_showEmojis)
            Container(
              margin: const EdgeInsets.only(bottom: 4, left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min,
                children: _emojis.keys.map((emoji) =>
                  GestureDetector(
                    onTap: () => _react(emoji),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ).toList(),
              ),
            ),

          // Bouton principal
          GestureDetector(
            onTap: () => setState(() => _showEmojis = !_showEmojis),
            onLongPress: () => setState(() => _showEmojis = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  myReaction ?? '❤️',
                  style: TextStyle(
                    fontSize: 20,
                    color: myReaction != null ? null : AppColors.textGrey,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${reactions.length}',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}

// ═══════════════════════════════════════
// 👥 MEMBRES EN LIGNE — Widget
// ═══════════════════════════════════════
// Ajoute dans ChatListScreen ou HomeScreen :
// const OnlineMembersBar(),

class OnlineMembersBar extends StatelessWidget {
  const OnlineMembersBar({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _featDb.collection('users')
          .where('online', isEqualTo: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = (snap.data?.docs ?? [])
            .where((d) => d.id != myUid)
            .toList();

        if (docs.isEmpty) return const SizedBox();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text('${docs.length} membre(s) en ligne',
                  style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data     = docs[i].data() as Map<String, dynamic>;
                  final name     = data['name']     ?? 'Membre';
                  final photoUrl = data['photoUrl'] ?? '';
                  return Tooltip(
                    message: name,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty
                              ? Text(name[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13))
                              : null,
                        ),
                        Positioned(right: 0, bottom: 0,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          )),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════
// 📊 STATS PERSONNELLES AVANCÉES
// ═══════════════════════════════════════
// Ajoute dans ProfileScreen :
// const AdvancedStatsSection(),

class AdvancedStatsSection extends StatelessWidget {
  const AdvancedStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mes statistiques',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      // Stats en grille
      StreamBuilder<QuerySnapshot>(
        stream: _featDb.collection('posts')
            .where('authorId', isEqualTo: uid).snapshots(),
        builder: (_, postsSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream: _featDb.collection('projects')
                .where('authorId', isEqualTo: uid).snapshots(),
            builder: (_, projSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: _featDb.collection('donations')
                    .where('donorId', isEqualTo: uid).snapshots(),
                builder: (_, donSnap) {
                  // Calculer total likes reçus
                  int totalLikes = 0;
                  for (final doc in postsSnap.data?.docs ?? []) {
                    final data = doc.data() as Map<String, dynamic>;
                    totalLikes += (data['reactions'] as Map?)?.length ?? 0;
                  }

                  // Total dons
                  double totalDons = 0;
                  for (final doc in donSnap.data?.docs ?? []) {
                    final data = doc.data() as Map<String, dynamic>;
                    totalDons += (data['amount'] as num?)?.toDouble() ?? 0;
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                    children: [
                      _AdvancedStatCard(
                        label: 'Publications',
                        value: '${postsSnap.data?.docs.length ?? 0}',
                        icon: Icons.article,
                        color: AppColors.primary,
                      ),
                      _AdvancedStatCard(
                        label: 'Réactions reçues',
                        value: '$totalLikes',
                        icon: Icons.favorite,
                        color: Colors.red,
                      ),
                      _AdvancedStatCard(
                        label: 'Projets créés',
                        value: '${projSnap.data?.docs.length ?? 0}',
                        icon: Icons.folder,
                        color: Colors.blue,
                      ),
                      _AdvancedStatCard(
                        label: 'Dons total',
                        value: '\$${totalDons.toStringAsFixed(0)}',
                        icon: Icons.volunteer_activism,
                        color: Colors.orange,
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),

      const SizedBox(height: 16),

      // Badge actuel
      StreamBuilder<DocumentSnapshot>(
        stream: _featDb.collection('users').doc(uid).snapshots(),
        builder: (_, snap) {
          final data  = snap.data?.data() as Map<String, dynamic>?;
          final badge = data?['badge'] ?? '';
          final tier  = data?['tier']  ?? '';
          if (badge.isEmpty) return const SizedBox();

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Text(badge, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Donateur $tier',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Text('Merci pour ton soutien ! 🙏',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ]),
          );
        },
      ),
    ]);
  }
}

class _AdvancedStatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _AdvancedStatCard({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(
            fontSize: 10, color: AppColors.textGrey),
            textAlign: TextAlign.center),
      ],
    ),
  );
}

// ═══════════════════════════════════════
// 🔔 NOTIFICATION SERVICE — Firebase FCM
// ═══════════════════════════════════════
// Instructions pour activer les notifications push :
//
// 1. pubspec.yaml ajoute :
//    firebase_messaging: ^15.0.0
//    flutter_local_notifications: ^17.0.0
//
// 2. Dans main.dart ajoute :
//    await NotificationService.init();
//
// 3. Dans AndroidManifest.xml ajoute :
//    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

class NotificationService {
  static Future<void> init() async {
    // TODO: Ajouter firebase_messaging quand tu as Firebase Cloud Messaging activé
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission();
    // final token = await messaging.getToken();
    // Sauvegarde le token dans Firestore pour envoyer des notifications ciblées
    debugPrint('NotificationService: prêt à configurer FCM');
  }

  // Sauvegarder le token FCM de l'utilisateur
  static Future<void> saveToken(String uid) async {
    // TODO: avec firebase_messaging:
    // final token = await FirebaseMessaging.instance.getToken();
    // await _featDb.collection('users').doc(uid).update({'fcmToken': token});
    debugPrint('FCM token saved for $uid');
  }
}
