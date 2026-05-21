import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendGroupMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    
    final user = _auth.currentUser;
    if (user == null) return;

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    // Récupère le vrai nom depuis Firestore
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final senderName = userDoc.data()?['name'] ?? user.displayName ?? 'Membre';
    final tier = userDoc.data()?['donationTier'] ?? 'none';

    await _db.collection('global_chat').add({
      'text': text,
      'senderId': user.uid,
      'senderName': senderName,
      'senderTier': tier,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Scroll automatique vers le bas
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _getBadge(String tier) {
    switch (tier) {
      case 'gold': return '👑 ';
      case 'silver': return '🥈 ';
      case 'bronze': return '🥉 ';
      case 'soutien': return '🤝 ';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salon Général UVDS 💬'),
      ),
      body: Column(
        children: [
          // ÉCOUTE EN TEMPS RÉEL (STREAM)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('global_chat')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun message... Lance la discussion ! 🎉',
                        style: TextStyle(color: AppColors.textGrey)),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true, // Les nouveaux messages apparaissent en bas
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == myUid;
                    final badge = _getBadge(data['senderTier'] ?? 'none');

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                            topLeft: !isMe ? const Radius.circular(0) : const Radius.circular(16),
                          ),
                          border: isMe ? null : Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                '$badge${data['senderName']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.accent,
                                ),
                              ),
                            if (!isMe) const SizedBox(height: 4),
                            Text(
                              data['text'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.white : AppColors.textDark,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ZONE DE SAISIE DU MESSAGE
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Écris ton message pour la commu...',
                      fillColor: AppColors.lightBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendGroupMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}