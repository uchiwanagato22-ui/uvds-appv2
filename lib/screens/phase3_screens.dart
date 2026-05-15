// ═══════════════════════════════════════════════════════
// UVDS V2 — PHASE 3 COMPLET
// Fichier : lib/screens/phase3_screens.dart
// ═══════════════════════════════════════════════════════
// Contient :
// 1. 💬 Messages privés
// 2. 🗺️ Carte projets (sans clé Maps)
// 3. 🎨 UI Animations
// 4. 📋 À propos UVDS
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

final _db = FirebaseFirestore.instance;

// ═══════════════════════════════════════
// 💬 MESSAGES PRIVÉS
// ═══════════════════════════════════════
// Comment ça marche :
// 1. Tu cliques sur un membre dans MembersScreen
// 2. Un chatId unique est créé entre les 2 users
// 3. Les messages sont dans Firestore
//
// Ajoute dans MembersScreen ListTile :
// onTap: () {
//   final myUid  = FirebaseAuth.instance.currentUser!.uid;
//   final hisUid = docs[i].id;
//   final chatId = myUid.compareTo(hisUid) < 0
//       ? '${myUid}_${hisUid}'
//       : '${hisUid}_${myUid}';
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => PrivateChatScreen(
//       chatId:       chatId,
//       otherUserId:  hisUid,
//       otherUserName: data['name'] ?? 'Membre',
//     ),
//   ));
// }

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const PrivateChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    final text = _ctrl.text.trim();
    _ctrl.clear();

    await _db
        .collection('private_chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'text':       text,
      'senderId':   user?.uid,
      'senderName': user?.displayName ?? 'Membre',
      'createdAt':  FieldValue.serverTimestamp(),
      'read':       false,
    });

    // Mettre à jour le dernier message
    await _db.collection('private_chats').doc(widget.chatId).set({
      'lastMessage':  text,
      'lastTime':     FieldValue.serverTimestamp(),
      'participants': [user?.uid, widget.otherUserId],
      'names': {
        user?.uid:          user?.displayName ?? 'Membre',
        widget.otherUserId: widget.otherUserName,
      },
    }, SetOptions(merge: true));

    // Notification
    await _db.collection('notifications').add({
      'uid':     widget.otherUserId,
      'message': '${user?.displayName} t\'a envoyé un message 💬',
      'read':    false,
      'time':    FieldValue.serverTimestamp(),
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: Text(
              widget.otherUserName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherUserName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            // Statut online
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('users').doc(widget.otherUserId).snapshots(),
              builder: (_, snap) {
                final online = (snap.data?.data() as Map?)?['online'] ?? false;
                return Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: online ? Colors.greenAccent : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(online ? 'En ligne' : 'Hors ligne',
                      style: const TextStyle(fontSize: 10, color: Colors.white70)),
                ]);
              },
            ),
          ]),
        ]),
      ),
      body: Column(children: [
        // Messages
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('private_chats')
              .doc(widget.chatId)
              .collection('messages')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;

            if (docs.isEmpty) return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    widget.otherUserName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Conversation avec ${widget.otherUserName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Envoie le premier message ! 👋',
                    style: TextStyle(color: AppColors.textGrey)),
              ]),
            );

            // Marquer comme lu
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) {
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              }
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['senderId'] != myUid && !(data['read'] ?? false)) {
                  doc.reference.update({'read': true});
                }
              }
            });

            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data  = docs[i].data() as Map<String, dynamic>;
                final isMe  = data['senderId'] == myUid;
                final ts    = data['createdAt'] as Timestamp?;
                final time  = ts != null
                    ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                    : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                          child: Text(
                            widget.otherUserName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.65,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.only(
                                topLeft:     const Radius.circular(18),
                                topRight:    const Radius.circular(18),
                                bottomLeft:  Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              border: isMe ? null : Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              data['text'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : null,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            Text(time,
                                style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                (data['read'] ?? false) ? Icons.done_all : Icons.done,
                                size: 12,
                                color: (data['read'] ?? false) ? Colors.blue : AppColors.textGrey,
                              ),
                            ],
                          ]),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        )),

        // Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.lightBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Liste des conversations privées ───
// Remplace le contenu de ChatListScreen dans all_screens.dart par :
//
// class ChatListScreen extends StatelessWidget {
//   const ChatListScreen({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final myUid = FirebaseAuth.instance.currentUser?.uid;
//     return Scaffold(
//       appBar: AppBar(title: const Text('Messages')),
//       body: Column(children: [
//         // Groupe UVDS en premier
//         ListTile(
//           onTap: () => Navigator.push(context,
//               MaterialPageRoute(builder: (_) => const GroupChatScreen())),
//           leading: Container(
//             width: 50, height: 50,
//             decoration: BoxDecoration(
//               gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2E8B57)]),
//               borderRadius: BorderRadius.circular(14),
//             ),
//             child: const Icon(Icons.group, color: Colors.white),
//           ),
//           title: const Text('Groupe UVDS 🌿', style: TextStyle(fontWeight: FontWeight.bold)),
//           subtitle: const Text('Chat général'),
//           trailing: const Icon(Icons.arrow_forward_ios, size: 14),
//         ),
//         const Divider(height: 1),
//         // Conversations privées
//         Expanded(child: StreamBuilder<QuerySnapshot>(
//           stream: _db.collection('private_chats')
//               .where('participants', arrayContains: myUid)
//               .orderBy('lastTime', descending: true)
//               .snapshots(),
//           builder: (_, snap) {
//             if (!snap.hasData) return const Center(child: CircularProgressIndicator());
//             final docs = snap.data!.docs;
//             if (docs.isEmpty) return const Center(
//               child: Text('Aucune conversation privée.\nVa dans Membres pour écrire !',
//                   textAlign: TextAlign.center,
//                   style: TextStyle(color: AppColors.textGrey)));
//             return ListView.builder(
//               itemCount: docs.length,
//               itemBuilder: (_, i) {
//                 final data    = docs[i].data() as Map<String, dynamic>;
//                 final names   = data['names'] as Map<String, dynamic>? ?? {};
//                 final parts   = List<String>.from(data['participants'] ?? []);
//                 final otherId = parts.firstWhere((p) => p != myUid, orElse: () => '');
//                 final otherName = names[otherId] ?? 'Membre';
//                 return ListTile(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(
//                     builder: (_) => PrivateChatScreen(
//                       chatId: docs[i].id,
//                       otherUserId: otherId,
//                       otherUserName: otherName,
//                     ),
//                   )),
//                   leading: CircleAvatar(
//                     backgroundColor: AppColors.primary.withValues(alpha: 0.2),
//                     child: Text(otherName[0].toUpperCase(),
//                         style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
//                   ),
//                   title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold)),
//                   subtitle: Text(data['lastMessage'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
//                   trailing: Text(_timeAgo(data['lastTime'] as Timestamp?),
//                       style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
//                 );
//               },
//             );
//           },
//         )),
//       ]),
//     );
//   }
// }

// ═══════════════════════════════════════
// 🗺️ CARTE PROJETS (sans clé Maps)
// ═══════════════════════════════════════
// Version simple avec liste + coordonnées
// Pour Google Maps : ajoute google_maps_flutter dans pubspec.yaml

class ProjectsMapScreen extends StatelessWidget {
  const ProjectsMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projets sur la carte 🗺️')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('projects').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          final withLocation = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['lat'] != null && data['lng'] != null;
          }).toList();

          if (withLocation.isEmpty) return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.map_outlined, size: 72, color: AppColors.textGrey),
              const SizedBox(height: 12),
              const Text('Aucun projet géolocalisé',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Ajoute une position lors de la création d\'un projet',
                  style: TextStyle(color: AppColors.textGrey),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              // Placeholder carte
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.map, size: 48, color: AppColors.textGrey),
                    SizedBox(height: 8),
                    Text('Carte disponible avec Google Maps API',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 12),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ]),
          );

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: withLocation.length,
            itemBuilder: (_, i) {
              final data   = withLocation[i].data() as Map<String, dynamic>;
              final status = data['status'] ?? 'En cours';
              final lat    = data['lat'] as double?;
              final lng    = data['lng'] as double?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on, color: AppColors.primary),
                  ),
                  title: Text(data['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: lat != null && lng != null
                      ? Text('📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12))
                      : null,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(status,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════
// 📋 À PROPOS UVDS
// ═══════════════════════════════════════
// Ajoute dans ProfileScreen :
// ListTile(
//   leading: Icon(Icons.info_outline, color: AppColors.primary),
//   title: Text('À propos de UVDS'),
//   onTap: () => Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const AboutScreen())),
// )

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        // Logo
        Center(child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: Image.asset('assets/images/logo_uvds.png', fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.balance, size: 50, color: AppColors.primary)),
          ),
        )),
        const SizedBox(height: 16),
        const Center(child: Text('UVDS',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary))),
        const Center(child: Text('Union pour la Vie et le Développement Social',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textGrey))),

        const SizedBox(height: 32),

        _AboutTile(icon: Icons.info, title: 'Mission',
            content: 'UVDS œuvre pour le développement social, l\'entraide et la solidarité entre les membres de la communauté.'),
        _AboutTile(icon: Icons.visibility, title: 'Vision',
            content: 'Un monde où chaque individu a accès aux ressources nécessaires pour vivre dignement.'),
        _AboutTile(icon: Icons.favorite, title: 'Valeurs',
            content: 'Unité • Volonté • Développement • Solidarité'),
        _AboutTile(icon: Icons.phone_android, title: 'Version app',
            content: 'UVDS App v2.0.0\nDéveloppé avec Flutter & Firebase'),

        const SizedBox(height: 24),

        // Stats globales
        const Text('UVDS en chiffres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(child: _AboutStat(label: 'Membres',
              stream: _db.collection('users').snapshots())),
          const SizedBox(width: 10),
          Expanded(child: _AboutStat(label: 'Projets',
              stream: _db.collection('projects').snapshots())),
          const SizedBox(width: 10),
          Expanded(child: _AboutStat(label: 'Posts',
              stream: _db.collection('posts').snapshots())),
        ]),

        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF2E8B57)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '"Ensemble pour un avenir meilleur" 🌿',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}

class _AboutTile extends StatelessWidget {
  final IconData icon; final String title, content;
  const _AboutTile({required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 22),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(color: AppColors.textGrey, height: 1.4)),
      ])),
    ]),
  );
}

class _AboutStat extends StatelessWidget {
  final String label; final Stream<QuerySnapshot> stream;
  const _AboutStat({required this.label, required this.stream});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text('${snap.data?.docs.length ?? 0}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
      ]),
    ),
  );
}
