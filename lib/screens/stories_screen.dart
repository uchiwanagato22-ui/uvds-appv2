import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

final _storyDb     = FirebaseFirestore.instance;
final _storyPicker = ImagePicker();

const String _cloudName    = 'dr1rbdtph';
const String _uploadPreset = 'uvds_preset';

Future<String?> _uploadStoryImage(File file) async {
  try {
    final url     = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    final body     = await response.stream.bytesToString();
    if (response.statusCode == 200) {
      return jsonDecode(body)['secure_url'] as String?;
    }
    return null;
  } catch (_) { return null; }
}

// ═══════════════════════════════════════
// STORIES WIDGET — à ajouter dans HomeScreen
// ═══════════════════════════════════════
// Ajoute ça dans HomeScreen body ListView AVANT les posts :
//
// const StoriesRow(),
// const SizedBox(height: 16),

class StoriesRow extends StatelessWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return SizedBox(
      height: 90,
      child: StreamBuilder<QuerySnapshot>(
        stream: _storyDb
            .collection('stories')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .orderBy('expiresAt', descending: false)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: docs.length + 1, // +1 pour "Ma story"
            itemBuilder: (_, i) {
              // Premier élément = ajouter ma story
              if (i == 0) {
                return GestureDetector(
                  onTap: () => _addStory(context),
                  child: Container(
                    width: 64,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(children: [
                      Stack(children: [
                        StreamBuilder<DocumentSnapshot>(
                          stream: _storyDb.collection('users').doc(myUid).snapshots(),
                          builder: (_, snap) {
                            final data     = snap.data?.data() as Map<String, dynamic>?;
                            final photoUrl = data?['photoUrl'] ?? '';
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl) : null,
                              child: photoUrl.isEmpty
                                  ? const Icon(Icons.person, color: AppColors.primary)
                                  : null,
                            );
                          },
                        ),
                        Positioned(right: 0, bottom: 0,
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 14),
                          )),
                      ]),
                      const SizedBox(height: 4),
                      const Text('Ma story',
                          style: TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                );
              }

              final doc  = docs[i - 1];
              final data = doc.data() as Map<String, dynamic>;
              final seen = List<String>.from(data['seenBy'] ?? []);
              final isSeen = seen.contains(myUid);

              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => StoryViewScreen(doc: doc))),
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSeen ? null : const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF2E8B57)],
                        ),
                        border: isSeen
                            ? Border.all(color: Colors.grey.shade300, width: 2)
                            : null,
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundImage: (data['imageUrl'] ?? '').isNotEmpty
                            ? NetworkImage(data['imageUrl']) : null,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: (data['imageUrl'] ?? '').isEmpty
                            ? Text((data['authorName'] ?? 'M')[0].toUpperCase(),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['authorName'] ?? 'Membre',
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addStory(BuildContext context) async {
    final picked = await _storyPicker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final user     = FirebaseAuth.instance.currentUser;
    final imageUrl = await _uploadStoryImage(File(picked.path));
    if (imageUrl == null) return;

    // Story expire dans 24h
    final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)));

    await _storyDb.collection('stories').add({
      'imageUrl':   imageUrl,
      'authorId':   user?.uid,
      'authorName': user?.displayName ?? 'Membre',
      'seenBy':     [],
      'createdAt':  FieldValue.serverTimestamp(),
      'expiresAt':  expiresAt,
    });
  }
}

// ─── Voir une story ───────────────────
class StoryViewScreen extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const StoryViewScreen({super.key, required this.doc});
  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward()..addListener(() {
      if (_ctrl.isCompleted && mounted) Navigator.pop(context);
    });
    _markSeen();
  }

  Future<void> _markSeen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await widget.doc.reference.update({
      'seenBy': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data     = widget.doc.data() as Map<String, dynamic>;
    final imageUrl = data['imageUrl'] ?? '';
    final author   = data['authorName'] ?? 'Membre';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          // Image plein écran
          if (imageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),

          // Barre de progression
          Positioned(top: 50, left: 16, right: 16,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => LinearProgressIndicator(
                value: _ctrl.value,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),

          // Infos auteur
          Positioned(top: 70, left: 16,
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.8),
                child: Text(author[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(author, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(_timeLeft(data['expiresAt'] as Timestamp?),
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ]),
          ),

          // Bouton fermer
          Positioned(top: 50, right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            )),
        ]),
      ),
    );
  }

  String _timeLeft(Timestamp? ts) {
    if (ts == null) return '';
    final diff = ts.toDate().difference(DateTime.now());
    if (diff.inHours > 0) return 'Expire dans ${diff.inHours}h';
    return 'Expire dans ${diff.inMinutes} min';
  }
}
