// ═══════════════════════════════════════════════════════
// UVDS V2 — PHASE 2 COMPLET
// Fichier : lib/screens/phase2_screens.dart
// ═══════════════════════════════════════════════════════
// Contient :
// 1. 🌙 Dark Mode (ThemeNotifier)
// 2. 🔍 SearchScreen
// 3. 🛡 AdminScreen
// 4. 📊 StatsScreen
// 5. 💰 DonationsScreen
// 6. 💬 PrivateChatScreen
// 7. 👥 MembersScreen
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/donation_service.dart';
import 'phase3_screens.dart';

final _db = FirebaseFirestore.instance;

// ═══════════════════════════════════════
// 🌙 THEME NOTIFIER (Dark Mode)
// ═══════════════════════════════════════
// Ajoute dans main.dart :
//
// import 'package:flutter/material.dart';
// final themeNotifier = ThemeNotifier();
//
// class UVDSApp extends StatefulWidget {
//   @override
//   State<UVDSApp> createState() => _UVDSAppState();
// }
// class _UVDSAppState extends State<UVDSApp> {
//   @override
//   void initState() {
//     super.initState();
//     themeNotifier.addListener(() => setState(() {}));
//   }
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       themeMode: themeNotifier.isDark ? ThemeMode.dark : ThemeMode.light,
//       theme: AppTheme.light,
//       darkTheme: AppTheme.dark,
//       ...
//     );
//   }
// }

class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;
  void toggle() { _isDark = !_isDark; notifyListeners(); }
}

final themeNotifier = ThemeNotifier();

// ═══════════════════════════════════════
// 🔍 SEARCH SCREEN
// ═══════════════════════════════════════
// Ajoute dans HomeScreen appBar actions :
// IconButton(
//   icon: Icon(Icons.search),
//   onPressed: () => Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const SearchScreen())),
// )

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl   = TextEditingController();
  String _query  = '';
  String _filter = 'Membres';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
        ),
      ),
      body: Column(children: [
        // Filtres
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: ['Membres', 'Posts', 'Projets'].map((f) =>
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filter == f ? AppColors.primary : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(f, style: TextStyle(
                    color: _filter == f ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  )),
                ),
              ),
            ),
          ).toList()),
        ),

        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection(
            _filter == 'Membres' ? 'users' :
            _filter == 'Posts'   ? 'posts' : 'projects'
          ).snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final searchIn = _filter == 'Membres'
                  ? '${data['name'] ?? ''} ${data['email'] ?? ''}'
                  : _filter == 'Posts'
                      ? '${data['text'] ?? ''} ${data['authorName'] ?? ''}'
                      : '${data['title'] ?? ''} ${data['desc'] ?? ''}';
              return _query.isEmpty || searchIn.toLowerCase().contains(_query);
            }).toList();

            if (docs.isEmpty) return const Center(
              child: Text('Aucun résultat', style: TextStyle(color: AppColors.textGrey)),
            );

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                if (_filter == 'Membres') return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage: (data['photoUrl'] ?? '').isNotEmpty
                        ? NetworkImage(data['photoUrl']) : null,
                    child: (data['photoUrl'] ?? '').isEmpty
                        ? Text((data['name'] ?? 'M')[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(data['email'] ?? ''),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(data['role'] ?? 'membre',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11)),
                  ),
                );

                if (_filter == 'Posts') return ListTile(
                  leading: const Icon(Icons.article, color: AppColors.primary),
                  title: Text(data['authorName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(data['text'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                );

                return ListTile(
                  leading: const Icon(Icons.folder, color: AppColors.primary),
                  title: Text(data['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(data['desc'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(data['status'] ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                  ),
                );
              },
            );
          },
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 👥 MEMBERS SCREEN
// ═══════════════════════════════════════
// Ajoute dans HomeScreen :
// ElevatedButton(
//   onPressed: () => Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const MembersScreen())),
//   child: Text('Voir les membres'),
// )

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membres UVDS 👥')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('users').orderBy('createdAt', descending: false).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data     = docs[i].data() as Map<String, dynamic>;
              final name     = data['name']     ?? 'Membre';
              final role     = data['role']     ?? 'membre';
              final photoUrl = data['photoUrl'] ?? '';
              final isAdmin  = role == 'admin';
              final isOnline = data['online']   ?? false;

              final memberId = docs[i].id;
              final myUid = FirebaseAuth.instance.currentUser?.uid;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  onTap: myUid == null || myUid == memberId
                      ? null
                      : () {
                          final chatId = myUid.compareTo(memberId) < 0
                              ? '${myUid}_$memberId'
                              : '${memberId}_$myUid';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PrivateChatScreen(
                                chatId: chatId,
                                otherUserId: memberId,
                                otherUserName: name,
                              ),
                            ),
                          );
                        },
                  leading: Stack(children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(name[0].toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    // Indicateur online
                    if (isOnline) Positioned(right: 0, bottom: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      )),
                  ]),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(data['email'] ?? ''),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAdmin ? Colors.orange.shade50 : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isAdmin ? Colors.orange : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
// 🛡 ADMIN SCREEN
// ═══════════════════════════════════════
// Ajoute dans HomeScreen (visible si role == 'admin') :
// GestureDetector(
//   onTap: () => Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const AdminScreen())),
//   child: Container(/* bouton admin orange */),
// )

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin 🛡'),
        backgroundColor: Colors.orange,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // Stats globales
        const Text('Statistiques globales',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _AdminStat(label: 'Membres', icon: Icons.people,
              color: AppColors.primary, stream: _db.collection('users').snapshots())),
          const SizedBox(width: 10),
          Expanded(child: _AdminStat(label: 'Posts', icon: Icons.article,
              color: Colors.blue, stream: _db.collection('posts').snapshots())),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _AdminStat(label: 'Projets', icon: Icons.folder,
              color: Colors.purple, stream: _db.collection('projects').snapshots())),
          const SizedBox(width: 10),
          Expanded(child: _AdminStat(label: 'Messages', icon: Icons.chat,
              color: Colors.teal, stream: _db.collection('chat_global').snapshots())),
        ]),

        const SizedBox(height: 24),

        const Text('Dons UVDS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('donations')
              .orderBy('createdAt', descending: true)
              .limit(20)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            double total = 0;
            for (final d in docs) {
              total += ((d.data() as Map)['amount'] as num?)?.toDouble() ?? 0;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.volunteer_activism,
                        color: AppColors.primary),
                    title: const Text('Total récent (20 derniers)'),
                    trailing: Text(
                      '\$${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Numéro : $uvdsPaymentNumber',
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12)),
                const SizedBox(height: 8),
                ...docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final method = data['method'] ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      title: Text(data['donorName'] ?? 'Anonyme',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${method == 'bankily' ? 'Bankily' : method == 'masrivi' ? 'Masrivi' : method} • ${data['reference'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '\$${(data['amount'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Gérer membres
        const Text('Gérer les membres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('users').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return Column(children: snap.data!.docs.map((doc) {
              final data    = doc.data() as Map<String, dynamic>;
              final role    = data['role']  ?? 'membre';
              final isAdmin = role == 'admin';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    child: Text((data['name'] ?? 'M')[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(data['email'] ?? ''),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'admin')  await _db.collection('users').doc(doc.id).update({'role': 'admin'});
                      if (v == 'membre') await _db.collection('users').doc(doc.id).update({'role': 'membre'});
                      if (v == 'delete') await _db.collection('users').doc(doc.id).delete();
                    },
                    itemBuilder: (_) => [
                      if (!isAdmin) const PopupMenuItem(value: 'admin',
                          child: Text('🛡 Passer Admin')),
                      if (isAdmin)  const PopupMenuItem(value: 'membre',
                          child: Text('👤 Passer Membre')),
                      const PopupMenuItem(value: 'delete',
                          child: Text('🗑 Supprimer', style: TextStyle(color: Colors.red))),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAdmin ? Colors.orange.shade50 : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(role.toUpperCase(),
                          style: TextStyle(fontSize: 11,
                              color: isAdmin ? Colors.orange : AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              );
            }).toList());
          },
        ),

        const SizedBox(height: 24),

        // Modération posts
        const Text('Modération posts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('posts').orderBy('createdAt', descending: true).snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const SizedBox();
            return Column(children: snap.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(data['authorName'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(data['text'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _db.collection('posts').doc(doc.id).delete(),
                  ),
                ),
              );
            }).toList());
          },
        ),
      ]),
    );
  }
}

class _AdminStat extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final Stream<QuerySnapshot> stream;
  const _AdminStat({required this.label, required this.icon,
      required this.color, required this.stream});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text('${snap.data?.docs.length ?? 0}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ]),
    ),
  );
}

// ═══════════════════════════════════════
// 📊 STATS SCREEN
// ═══════════════════════════════════════
// Ajoute dans HomeScreen :
// IconButton(
//   icon: Icon(Icons.bar_chart),
//   onPressed: () => Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const StatsScreen())),
// )

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques 📊')),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        const Text('Vue globale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Grille stats
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _StatTile(label: 'Membres', icon: Icons.people, color: AppColors.primary,
                stream: _db.collection('users').snapshots()),
            _StatTile(label: 'Publications', icon: Icons.article, color: Colors.blue,
                stream: _db.collection('posts').snapshots()),
            _StatTile(label: 'Projets', icon: Icons.folder, color: Colors.purple,
                stream: _db.collection('projects').snapshots()),
            _StatTile(label: 'Messages', icon: Icons.chat, color: Colors.teal,
                stream: _db.collection('chat_global').snapshots()),
          ],
        ),

        const SizedBox(height: 24),

        // Projets par statut
        const Text('Projets par statut',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('projects').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs    = snap.data!.docs;
            final enCours = docs.where((d) => (d.data() as Map)['status'] == 'En cours').length;
            final planifie = docs.where((d) => (d.data() as Map)['status'] == 'Planifié').length;
            final termine  = docs.where((d) => (d.data() as Map)['status'] == 'Terminé').length;
            final total    = docs.length;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _StatusBar(label: 'En cours', count: enCours, total: total, color: AppColors.primary),
                  const SizedBox(height: 12),
                  _StatusBar(label: 'Planifié', count: planifie, total: total, color: Colors.blue),
                  const SizedBox(height: 12),
                  _StatusBar(label: 'Terminé', count: termine, total: total, color: Colors.grey),
                ]),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Membres par rôle
        const Text('Membres par rôle',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('users').snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs    = snap.data!.docs;
            final admins  = docs.where((d) => (d.data() as Map)['role'] == 'admin').length;
            final membres = docs.length - admins;
            final total   = docs.length;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _StatusBar(label: 'Membres', count: membres, total: total, color: AppColors.primary),
                  const SizedBox(height: 12),
                  _StatusBar(label: 'Admins', count: admins, total: total, color: Colors.orange),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final Stream<QuerySnapshot> stream;
  const _StatTile({required this.label, required this.icon,
      required this.color, required this.stream});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text('${snap.data?.docs.length ?? 0}',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ]),
    ),
  );
}

class _StatusBar extends StatelessWidget {
  final String label; final int count, total; final Color color;
  const _StatusBar({required this.label, required this.count,
      required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
        ),
      ),
    ]);
  }
}

// DonationsScreen → lib/screens/donations_screen.dart

// ═══════════════════════════════════════
// 🌙 DARK MODE SWITCH
// ═══════════════════════════════════════
// Ajoute dans ProfileScreen :
//
// AnimatedBuilder(
//   animation: themeNotifier,
//   builder: (_, __) => SwitchListTile(
//     title: const Text('Mode sombre 🌙'),
//     value: themeNotifier.isDark,
//     onChanged: (_) => themeNotifier.toggle(),
//     activeColor: AppColors.primary,
//   ),
// ),
