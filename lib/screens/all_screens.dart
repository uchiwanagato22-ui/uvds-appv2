// ═══════════════════════════════════════════════════════
// UVDS V2 — all_screens.dart CORRIGÉ COMPLET
// Fixes :
// ✅ Nom réel depuis Firestore (plus "Membre")
// ✅ Images qui s'affichent vraiment
// ✅ Projets modifiables + statut + détail
// ✅ Chat amélioré
// ✅ Profil réel
// ═══════════════════════════════════════════════════════

import 'donations_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'phase2_screens.dart';
import 'admin_screen.dart';

final _db      = FirebaseFirestore.instance;
final _picker  = ImagePicker();

// ─── Helper upload image ───────────────
// Cloudinary config
const String _cloudName    = 'dr1rbdtph';
const String _uploadPreset = 'uvds_preset';

Future<String?> uploadImage(File file, String path) async {
  try {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body)['secure_url'] as String?;
    }
    return null;
  } catch (e) {
    debugPrint('Upload error: $e');
    return null;
  }
}

// ─── Helper time ago ──────────────────
String timeAgo(Timestamp? ts) {
  if (ts == null) return '...';
  final diff = DateTime.now().difference(ts.toDate());
  if (diff.inSeconds < 60)  return 'À l\'instant';
  if (diff.inMinutes < 60)  return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24)    return 'Il y a ${diff.inHours}h';
  if (diff.inDays < 7)      return 'Il y a ${diff.inDays} jour(s)';
  return '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}';
}

// ─── Helper : récupère le vrai nom ────
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

// ═══════════════════════════════════════
// HOME SCREEN
// ═══════════════════════════════════════
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/logo_uvds.png', height: 32,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.balance, color: Colors.white, size: 28)),
          const SizedBox(width: 8),
          const Text('UVDS'),
        ]),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('notifications')
                .where('uid', isEqualTo: uid)
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                if (count > 0) Positioned(right: 6, top: 6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Center(child: Text('$count',
                        style: const TextStyle(color: Colors.white, fontSize: 9))),
                  )),
              ]);
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Bannière avec vrai nom
        StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('users').doc(uid).snapshots(),
          builder: (_, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            final name = data?['name'] ?? 
                         FirebaseAuth.instance.currentUser?.displayName ?? 
                         'Membre';
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF2E8B57)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bonjour, $name 👋',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                const Text('Ensemble pour un avenir meilleur 🌿',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('users').snapshots(),
                    builder: (_, s) => _BannerChip(
                      icon: Icons.people, label: '${s.data?.docs.length ?? 0} membres'),
                  ),
                  const SizedBox(width: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('projects').snapshots(),
                    builder: (_, s) => _BannerChip(
                      icon: Icons.folder, label: '${s.data?.docs.length ?? 0} projets'),
                  ),
                ]),
              ]),
            );
          },
        ),

        const SizedBox(height: 20),

        StreamBuilder<DocumentSnapshot>(
          stream: _db.collection('users').doc(uid).snapshots(),
          builder: (_, userSnap) {
            final userData =
                userSnap.data?.data() as Map<String, dynamic>?;
            final isAdmin = (userData?['role'] ?? '') == 'admin';
            return Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.volunteer_activism, size: 20),
                  label: const Text('Faire un don'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DonationsScreen()),
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.admin_panel_settings, size: 20),
                    label: const Text('Admin'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AdminScreen()),
                    ),
                  ),
                ),
              ],
            ]);
          },
        ),

        const SizedBox(height: 20),

        Row(children: [
          _StatCard(label: 'Publications', icon: Icons.article,
              stream: _db.collection('posts').snapshots()),
          const SizedBox(width: 12),
          _StatCard(label: 'Messages', icon: Icons.chat,
              stream: _db.collection('chat_global').snapshots()),
        ]),

        const SizedBox(height: 20),

        const Text('Dernières publications',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('posts')
              .orderBy('createdAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(
              child: Text('Aucune publication', style: TextStyle(color: AppColors.textGrey)),
            );
            return Column(children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _MiniPostCard(data: data);
            }).toList());
          },
        ),
      ]),
    );
  }
}

class _BannerChip extends StatelessWidget {
  final IconData icon; final String label;
  const _BannerChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.white),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String label; final IconData icon; final Stream<QuerySnapshot> stream;
  const _StatCard({required this.label, required this.icon, required this.stream});
  @override
  Widget build(BuildContext context) => Expanded(
    child: StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${snap.data?.docs.length ?? 0}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class _MiniPostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MiniPostCard({required this.data});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        child: Text(
          (data['authorName'] ?? 'M')[0].toUpperCase(),
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(data['authorName'] ?? 'Membre',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        data['text'] ?? '',
        maxLines: 2, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: Text(timeAgo(data['createdAt'] as Timestamp?),
          style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
    ),
  );
}

// ═══════════════════════════════════════
// POSTS SCREEN — CORRIGÉ
// ✅ Vrai nom depuis Firestore
// ✅ Image qui s'affiche
// ═══════════════════════════════════════
class PostsScreen extends StatefulWidget {
  const PostsScreen({super.key});
  @override
  State<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends State<PostsScreen> {
  final _textCtrl = TextEditingController();
  File? _image;
  bool _uploading = false;

  void _showNewPost() async {
    // Récupère le vrai nom AVANT d'ouvrir le modal
    final realName = await getRealName();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Nouvelle publication',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Auteur avec vrai nom
            Row(children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(realName[0].toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(realName, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),

            TextField(
              controller: _textCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Quoi de neuf pour UVDS ?',
                border: InputBorder.none,
              ),
            ),

            // Aperçu image sélectionnée
            if (_image != null) ...[
              const SizedBox(height: 8),
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(_image!, height: 180, width: double.infinity,
                      fit: BoxFit.cover),
                ),
                Positioned(top: 8, right: 8,
                  child: GestureDetector(
                    onTap: () => setModal(() => _image = null),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  )),
              ]),
            ],

            const SizedBox(height: 12),
            Row(children: [
              // Bouton photo
              IconButton(
                icon: const Icon(Icons.photo_library, color: AppColors.primary),
                onPressed: () async {
                  final picked = await _picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) setModal(() => _image = File(picked.path));
                },
              ),
              IconButton(
                icon: const Icon(Icons.camera_alt, color: AppColors.primary),
                onPressed: () async {
                  final picked = await _picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) setModal(() => _image = File(picked.path));
                },
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
                onPressed: _uploading ? null : () async {
                  if (_textCtrl.text.trim().isEmpty && _image == null) return;
                  setModal(() => _uploading = true);

                  // Upload image Firebase Storage
                  String? imageUrl;
                  if (_image != null) {
                    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
                    imageUrl = await uploadImage(_image!, 'posts/$fileName');
                  }

                  final user = FirebaseAuth.instance.currentUser;

                  // Sauvegarde dans Firestore avec vrai nom
                  await _db.collection('posts').add({
                    'text':       _textCtrl.text.trim(),
                    'imageUrl':   imageUrl ?? '',
                    'authorId':   user?.uid,
                    'authorName': realName, // ← vrai nom !
                    'likes':      [],
                    'createdAt':  FieldValue.serverTimestamp(),
                  });

                  _textCtrl.clear();
                  setState(() => _image = null);
                  setModal(() => _uploading = false);
                  if (mounted) Navigator.pop(context);
                },
                child: _uploading
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Publier'),
              ),
            ]),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publications')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showNewPost,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.article_outlined, size: 72, color: AppColors.textGrey),
              SizedBox(height: 12),
              Text('Aucune publication',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
              Text('Appuie sur + pour écrire',
                  style: TextStyle(color: AppColors.textGrey)),
            ]),
          );
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) => PostCard(doc: docs[i]),
          );
        },
      ),
    );
  }
}

// ─── Post Card CORRIGÉ ────────────────
class PostCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const PostCard({super.key, required this.doc});

  Future<void> _toggleLike() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final data  = doc.data() as Map<String, dynamic>;
    final likes = List<String>.from(data['likes'] ?? []);
    likes.contains(uid) ? likes.remove(uid) : likes.add(uid);
    await _db.collection('posts').doc(doc.id).update({'likes': likes});

    if (likes.contains(uid) && data['authorId'] != uid) {
      await _db.collection('notifications').add({
        'uid':     data['authorId'],
        'message': '${FirebaseAuth.instance.currentUser?.displayName} a aimé ton post ❤️',
        'read':    false,
        'time':    FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data      = doc.data() as Map<String, dynamic>;
    final uid       = FirebaseAuth.instance.currentUser?.uid;
    final likes     = List<String>.from(data['likes'] ?? []);
    final isLiked   = likes.contains(uid);
    final author    = data['authorName'] ?? 'Membre';
    final imageUrl  = (data['imageUrl'] ?? '').toString().trim();
    final isOwner   = data['authorId'] == uid;
    final text      = (data['text'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ─── Header ───────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Avatar avec photo profil
            StreamBuilder<DocumentSnapshot>(
              stream: _db.collection('users').doc(data['authorId']).snapshots(),
              builder: (_, snap) {
                final uData    = snap.data?.data() as Map<String, dynamic>?;
                final photoUrl = uData?['photoUrl'] ?? '';
                return CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(author[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                      : null,
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(author, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(timeAgo(data['createdAt'] as Timestamp?),
                  style: const TextStyle(fontSize: 11, color: AppColors.textGrey)),
            ])),
            if (isOwner) IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textGrey, size: 20),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer ?'),
                  content: const Text('Ce post sera supprimé définitivement.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler')),
                    TextButton(
                      onPressed: () {
                        _db.collection('posts').doc(doc.id).delete();
                        Navigator.pop(context);
                      },
                      child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // ─── Texte ────────────────────
        if (text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
          ),

        // ─── Image CORRIGÉE ───────────
        if (imageUrl.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 220,
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                              progress.expectedTotalBytes!
                          : null,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                height: 100,
                color: AppColors.primary.withValues(alpha: 0.05),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.textGrey, size: 40),
                ),
              ),
            ),
          ),
        ],

        // ─── Actions ──────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            // Like
            TextButton.icon(
              onPressed: _toggleLike,
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : AppColors.textGrey,
                size: 20,
              ),
              label: Text('${likes.length}',
                  style: TextStyle(
                      color: isLiked ? Colors.red : AppColors.textGrey)),
            ),
            // Commentaires
            TextButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CommentsScreen(
                      postId: doc.id,
                      postAuthorId: data['authorId'] ?? ''))),
              icon: const Icon(Icons.comment_outlined,
                  color: AppColors.textGrey, size: 20),
              label: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('posts').doc(doc.id)
                    .collection('comments').snapshots(),
                builder: (_, s) => Text('${s.data?.docs.length ?? 0}',
                    style: const TextStyle(color: AppColors.textGrey)),
              ),
            ),
            const Spacer(),
            // Partager
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: AppColors.textGrey, size: 20),
              onPressed: () => Share.share(
                  '${text.isNotEmpty ? text : 'Post UVDS'}\n\n— Partagé depuis UVDS 🌿'),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// COMMENTS SCREEN
// ═══════════════════════════════════════
class CommentsScreen extends StatefulWidget {
  final String postId, postAuthorId;
  const CommentsScreen({super.key, required this.postId, required this.postAuthorId});
  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _ctrl = TextEditingController();

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    final realName = await getRealName();
    final user = FirebaseAuth.instance.currentUser;
    final text = _ctrl.text.trim();
    _ctrl.clear();

    await _db.collection('posts').doc(widget.postId)
        .collection('comments').add({
      'text':       text,
      'authorName': realName, // ← vrai nom
      'authorId':   user?.uid,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    if (widget.postAuthorId != user?.uid) {
      await _db.collection('notifications').add({
        'uid':     widget.postAuthorId,
        'message': '$realName a commenté ton post 💬',
        'read':    false,
        'time':    FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commentaires')),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('posts').doc(widget.postId)
              .collection('comments').orderBy('createdAt').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(
              child: Text('Aucun commentaire — sois le premier ! 💬',
                  style: TextStyle(color: AppColors.textGrey)),
            );
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text((d['authorName'] ?? 'M')[0].toUpperCase(),
                          style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['authorName'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(d['text'] ?? ''),
                      const SizedBox(height: 4),
                      Text(timeAgo(d['createdAt'] as Timestamp?),
                          style: const TextStyle(fontSize: 10, color: AppColors.textGrey)),
                    ])),
                  ]),
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
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Commenter...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                filled: true, fillColor: AppColors.lightBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// CHAT LIST SCREEN
// ═══════════════════════════════════════
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Column(children: [
        ListTile(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const GroupChatScreen())),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF2E8B57)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.group, color: Colors.white),
          ),
          title: const Text('Groupe UVDS 🌿',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('chat_global')
                .orderBy('createdAt', descending: true)
                .limit(1)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return const Text('Aucun message');
              }
              final data = snap.data!.docs.first.data() as Map<String, dynamic>;
              return Text('${data['authorName']}: ${data['text']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis);
            },
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textGrey),
        ),
        const Divider(height: 1),
        const Expanded(child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: AppColors.textGrey),
            SizedBox(height: 12),
            Text('Messages privés disponibles bientôt',
                style: TextStyle(color: AppColors.textGrey)),
          ]),
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// GROUP CHAT SCREEN — CORRIGÉ
// ✅ Vrai nom
// ═══════════════════════════════════════
class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});
  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    final realName = await getRealName();
    final user = FirebaseAuth.instance.currentUser;
    final text = _ctrl.text.trim();
    _ctrl.clear();

    await _db.collection('chat_global').add({
      'text':       text,
      'authorName': realName, // ← vrai nom
      'authorId':   user?.uid,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.group, size: 20),
          SizedBox(width: 8),
          Text('Groupe UVDS'),
        ]),
      ),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('chat_global').orderBy('createdAt').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(
              child: Text('Sois le premier à écrire ! 👋',
                  style: TextStyle(color: AppColors.textGrey)),
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) {
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              }
            });
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                return _ChatBubble(data: data, isMe: data['authorId'] == myUid);
              },
            );
          },
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'Message...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none),
                filled: true, fillColor: AppColors.lightBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Map<String, dynamic> data; final bool isMe;
  const _ChatBubble({required this.data, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final ts     = data['createdAt'] as Timestamp?;
    final time   = ts != null
        ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';
    final author = data['authorName'] ?? 'Membre';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(author[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(author,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                          fontWeight: FontWeight.w600)),
                ),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(18),
                    topRight:    const Radius.circular(18),
                    bottomLeft:  Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe ? null : Border.all(color: AppColors.border),
                ),
                child: Text(data['text'] ?? '',
                    style: TextStyle(
                        color: isMe ? Colors.white : null, fontSize: 14)),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(time,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textGrey)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════
// PROJECTS SCREEN — CORRIGÉ
// ✅ Modifier statut
// ✅ Supprimer
// ✅ Page détail
// ✅ Statuts : En cours / Planifié / Terminé / Annulé
// ═══════════════════════════════════════
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _status   = 'En cours';
  File? _projectImage;
  bool _uploadingProject = false;

  void _showAdd() {
    _titleCtrl.clear();
    _descCtrl.clear();
    _status = 'En cours';
    _projectImage = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Nouveau projet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl,
                decoration: const InputDecoration(
                    hintText: 'Titre du projet',
                    prefixIcon: Icon(Icons.folder_outlined))),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, maxLines: 3,
                decoration: const InputDecoration(hintText: 'Description')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: ['En cours', 'Planifié', 'Terminé', 'Annulé']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setModal(() => _status = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 75);
                if (picked != null) {
                  setModal(() => _projectImage = File(picked.path));
                }
              },
              icon: const Icon(Icons.photo_library, color: AppColors.primary),
              label: Text(_projectImage == null
                  ? 'Ajouter une photo'
                  : 'Photo sélectionnée ✓'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _uploadingProject ? null : () async {
                if (_titleCtrl.text.trim().isEmpty) return;
                setModal(() => _uploadingProject = true);
                final realName = await getRealName();
                String imageUrl = '';
                if (_projectImage != null) {
                  final fileName =
                      '${DateTime.now().millisecondsSinceEpoch}.jpg';
                  imageUrl = await uploadImage(
                          _projectImage!, 'projects/$fileName') ??
                      '';
                }
                await _db.collection('projects').add({
                  'title':     _titleCtrl.text.trim(),
                  'desc':      _descCtrl.text.trim(),
                  'status':    _status,
                  'imageUrl':  imageUrl,
                  'createdBy': realName,
                  'authorId':  FirebaseAuth.instance.currentUser?.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
                setState(() => _uploadingProject = false);
              },
              child: _uploadingProject
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Créer le projet'),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'En cours': return AppColors.primary;
      case 'Planifié': return Colors.blue;
      case 'Terminé':  return Colors.green;
      case 'Annulé':   return Colors.red;
      default:         return AppColors.primary;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'En cours': return Icons.play_circle_outline;
      case 'Planifié': return Icons.schedule;
      case 'Terminé':  return Icons.check_circle_outline;
      case 'Annulé':   return Icons.cancel_outlined;
      default:         return Icons.folder;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projets ONG')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: _showAdd,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('projects')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.folder_outlined, size: 72, color: AppColors.textGrey),
              SizedBox(height: 12),
              Text('Aucun projet', style: TextStyle(color: AppColors.textGrey, fontSize: 16)),
              Text('Appuie sur + pour créer', style: TextStyle(color: AppColors.textGrey)),
            ]),
          );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data    = docs[i].data() as Map<String, dynamic>;
              final status  = data['status'] ?? 'En cours';
              final color   = _statusColor(status);
              final icon    = _statusIcon(status);
              final isOwner = data['authorId'] == FirebaseAuth.instance.currentUser?.uid;
              final imageUrl = (data['imageUrl'] ?? '').toString().trim();

              return GestureDetector(
                // ← Ouvre la page détail au clic
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(
                    projectId: docs[i].id,
                    data: data,
                  ),
                )),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(data['title'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Par ${data['createdBy'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textGrey)),
                        ])),
                        // Statut + menu si propriétaire
                        Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(status,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: color,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (isOwner) PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'delete') {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Supprimer ?'),
                                    content: const Text('Ce projet sera supprimé.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text('Annuler')),
                                      TextButton(
                                        onPressed: () {
                                          _db.collection('projects').doc(docs[i].id).delete();
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Supprimer',
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // Changer le statut
                                await _db.collection('projects')
                                    .doc(docs[i].id)
                                    .update({'status': v});
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'En cours',
                                  child: Text('▶️ En cours')),
                              const PopupMenuItem(value: 'Planifié',
                                  child: Text('🕐 Planifié')),
                              const PopupMenuItem(value: 'Terminé',
                                  child: Text('✅ Terminé')),
                              const PopupMenuItem(value: 'Annulé',
                                  child: Text('❌ Annulé')),
                              const PopupMenuDivider(),
                              const PopupMenuItem(value: 'delete',
                                  child: Text('🗑 Supprimer',
                                      style: TextStyle(color: Colors.red))),
                            ],
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textGrey, size: 20),
                          ),
                        ]),
                      ]),

                      if (imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ],

                      if ((data['desc'] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(data['desc'],
                            style: const TextStyle(
                                color: AppColors.textGrey, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],

                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 12, color: AppColors.textGrey),
                        const SizedBox(width: 4),
                        Text(timeAgo(data['createdAt'] as Timestamp?),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textGrey)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios,
                            size: 12, color: AppColors.textGrey),
                      ]),
                    ]),
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
// PROJECT DETAIL SCREEN — NOUVEAU
// ✅ Page détail complète
// ✅ Modifier statut
// ✅ Modifier titre/desc
// ═══════════════════════════════════════
class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  final Map<String, dynamic> data;
  const ProjectDetailScreen(
      {super.key, required this.projectId, required this.data});
  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late String _status;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _status   = widget.data['status'] ?? 'En cours';
    _titleCtrl = TextEditingController(text: widget.data['title'] ?? '');
    _descCtrl  = TextEditingController(text: widget.data['desc'] ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'En cours': return AppColors.primary;
      case 'Planifié': return Colors.blue;
      case 'Terminé':  return Colors.green;
      case 'Annulé':   return Colors.red;
      default:         return AppColors.primary;
    }
  }

  Future<void> _saveChanges() async {
    await _db.collection('projects').doc(widget.projectId).update({
      'title':  _titleCtrl.text.trim(),
      'desc':   _descCtrl.text.trim(),
      'status': _status,
    });
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projet mis à jour ✅'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.data['authorId'] ==
        FirebaseAuth.instance.currentUser?.uid;
    final color = _statusColor(_status);
    final imageUrl = (widget.data['imageUrl'] ?? '').toString().trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail projet'),
        actions: [
          if (isOwner)
            IconButton(
              icon: Icon(_editing ? Icons.close : Icons.edit),
              onPressed: () => setState(() => _editing = !_editing),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          if (imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Statut
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
            if (isOwner && _editing) ...[
              const SizedBox(width: 12),
              // Changer statut
              DropdownButton<String>(
                value: _status,
                items: ['En cours', 'Planifié', 'Terminé', 'Annulé']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
            ],
          ]),

          const SizedBox(height: 20),

          // Titre
          const Text('Titre', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          const SizedBox(height: 4),
          _editing
              ? TextField(controller: _titleCtrl,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
              : Text(_titleCtrl.text,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),

          // Description
          const Text('Description',
              style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
          const SizedBox(height: 4),
          _editing
              ? TextField(controller: _descCtrl, maxLines: 5,
                  decoration: const InputDecoration(
                      hintText: 'Description du projet'))
              : Text(_descCtrl.text.isNotEmpty
                  ? _descCtrl.text
                  : 'Aucune description',
                  style: const TextStyle(fontSize: 15, height: 1.5,
                      color: AppColors.textGrey)),

          const SizedBox(height: 20),

          // Info créateur
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: const Text('Créé par'),
              subtitle: Text(widget.data['createdBy'] ?? 'Membre'),
              trailing: Text(
                timeAgo(widget.data['createdAt'] as Timestamp?),
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ),
          ),

          if (_editing) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Sauvegarder les modifications'),
              onPressed: _saveChanges,
            ),
          ],

          if (!_editing && isOwner) ...[
            const SizedBox(height: 24),
            // Boutons statut rapides
            const Text('Changer le statut :',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ['En cours', 'Planifié', 'Terminé', 'Annulé']
                .map((s) => ActionChip(
                  label: Text(s),
                  backgroundColor: _status == s
                      ? _statusColor(s).withValues(alpha: 0.2)
                      : null,
                  labelStyle: TextStyle(
                      color: _status == s ? _statusColor(s) : null,
                      fontWeight: _status == s ? FontWeight.bold : null),
                  onPressed: () async {
                    setState(() => _status = s);
                    await _db.collection('projects')
                        .doc(widget.projectId)
                        .update({'status': s});
                  },
                )).toList()),

            const SizedBox(height: 24),

            // Supprimer
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Supprimer ce projet',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Supprimer ?'),
                  content: const Text('Ce projet sera supprimé définitivement.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler')),
                    TextButton(
                      onPressed: () {
                        _db.collection('projects').doc(widget.projectId).delete();
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: const Text('Supprimer',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════
// PROFILE SCREEN — CORRIGÉ
// ✅ Vrai nom depuis Firestore
// ✅ Photo profil
// ✅ Bio modifiable
// ═══════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final picked = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75);
    if (picked == null) return;
    setState(() => _uploading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final url = await uploadImage(File(picked.path), 'profiles/$uid.jpg');
    if (url != null && uid != null) {
      await _db.collection('users').doc(uid).update({'photoUrl': url});
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _saveUserField(Map<String, dynamic> fields) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(fields, SetOptions(merge: true));
  }

  void _editName(String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier mon nom'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Ton nom complet'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.length < 2) return;
              try {
                await FirebaseAuth.instance.currentUser
                    ?.updateDisplayName(name);
                await _saveUserField({'name': name});
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Nom mis à jour ✅'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _editBio(String currentBio) {
    final ctrl = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier ma bio'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 150,
          decoration: const InputDecoration(hintText: 'Parle de toi...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _saveUserField({'bio': ctrl.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bio enregistrée ✅'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur : $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon Profil')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(user?.uid).snapshots(),
        builder: (_, snap) {
          final data     = snap.data?.data() as Map<String, dynamic>?;
          final name     = data?['name']     ?? user?.displayName ?? 'Membre';
          final email    = data?['email']    ?? user?.email ?? '';
          final role     = data?['role']     ?? 'membre';
          final tier     = data?['donationTier'] ?? 'none';
          final totalDon = (data?['totalDonated'] as num?)?.toDouble() ?? 0;
          final photoUrl = data?['photoUrl'] ?? '';
          final bio      = data?['bio']      ?? '';
          final isAdmin  = (data?['role'] ?? '') == 'admin';

          return ListView(padding: const EdgeInsets.all(24), children: [
            // Avatar
            Center(child: Stack(children: [
              CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'M',
                        style: const TextStyle(
                            fontSize: 44,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              Positioned(
                right: 0, bottom: 0,
                child: GestureDetector(
                  onTap: _uploading ? null : _changePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: _uploading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt,
                            color: Colors.white, size: 16),
                  ),
                ),
              ),
            ])),

            const SizedBox(height: 16),

            // Nom (modifiable)
            Center(
              child: InkWell(
                onTap: () => _editName(name),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 16, color: AppColors.textGrey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Rôle + palier don
            Center(child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(role.toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                if (tier != 'none')
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        tier.toString().toUpperCase(),
                        style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
              ],
            )),
            if (totalDon > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    'Total dons : \$${totalDon.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Bio
            GestureDetector(
              onTap: () => _editBio(bio),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  Expanded(child: Text(
                    bio.isNotEmpty ? bio : 'Ajoute une bio...',
                    style: TextStyle(
                        color: bio.isNotEmpty
                            ? null
                            : AppColors.textGrey,
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  )),
                  const Icon(Icons.edit, size: 16, color: AppColors.textGrey),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // Stats perso
            Row(children: [
              Expanded(child: _ProfileStat(label: 'Posts',
                  stream: _db.collection('posts')
                      .where('authorId', isEqualTo: user?.uid).snapshots())),
              const SizedBox(width: 12),
              Expanded(child: _ProfileStat(label: 'Projets',
                  stream: _db.collection('projects')
                      .where('authorId', isEqualTo: user?.uid).snapshots())),
            ]),

            const SizedBox(height: 24),

            _InfoTile(icon: Icons.email_outlined, label: 'Email', value: email),
            _InfoTile(icon: Icons.badge_outlined,  label: 'Rôle',  value: role),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Faire un don — Bankily / Masrivi'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DonationsScreen()),
              ),
            ),

            if (isAdmin) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Panel Admin'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminScreen()),
                ),
              ),
            ] else if ((data?['role'] ?? '') == 'silver' || (data?['role'] ?? '') == 'gold') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.bar_chart, color: AppColors.primary),
                label: const Text('Statistiques communauté'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StatsScreen()),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Déconnexion
            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Se déconnecter',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => AuthService.logout(),
            ),
          ]);
        },
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label; final Stream<QuerySnapshot> stream;
  const _ProfileStat({required this.label, required this.stream});
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Text('${snap.data?.docs.length ?? 0}',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          Text(label, style: const TextStyle(color: AppColors.textGrey)),
        ]),
      ),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label, value;
  const _InfoTile({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
      subtitle: Text(value,
          style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

// ═══════════════════════════════════════
// NOTIFICATIONS SCREEN
// ═══════════════════════════════════════
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final notifs = await _db.collection('notifications')
                  .where('uid', isEqualTo: uid)
                  .where('read', isEqualTo: false)
                  .get();
              for (final doc in notifs.docs) {
                await doc.reference.update({'read': true});
              }
            },
            child: const Text('Tout lire',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('notifications')
            .where('uid', isEqualTo: uid)
            .orderBy('time', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_none, size: 72, color: AppColors.textGrey),
              SizedBox(height: 12),
              Text('Aucune notification',
                  style: TextStyle(color: AppColors.textGrey)),
            ]),
          );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data  = docs[i].data() as Map<String, dynamic>;
              final isNew = !(data['read'] ?? true);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isNew
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isNew
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.notifications,
                      color: isNew ? AppColors.primary : AppColors.textGrey),
                  const SizedBox(width: 12),
                  Expanded(child: Text(data['message'] ?? '',
                      style: TextStyle(
                          fontWeight: isNew
                              ? FontWeight.bold
                              : FontWeight.normal))),
                  if (isNew)
                    GestureDetector(
                      onTap: () => docs[i].reference.update({'read': true}),
                      child: const Icon(Icons.check_circle_outline,
                          color: AppColors.primary, size: 20),
                    ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
