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
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';

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

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
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

// ═══════════════════════════════════════
// 💰 DONATIONS SCREEN
// ═══════════════════════════════════════
// Ajoute dans HomeScreen ou ProfileScreen :
// ElevatedButton.icon(
//   icon: Icon(Icons.volunteer_activism),
//   label: Text('Faire un don'),
//   onPressed: () => Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const DonationsScreen())),
// )

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  double _amount    = 10;
  String _message   = '';
  bool   _loading   = false;
  bool   _success   = false;

  final List<double> _presets = [5, 10, 25, 50, 100];

  Future<void> _donate() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;

    // Enregistre le don dans Firestore
    // En production → intègre Stripe ou PayPal ici
    await _db.collection('donations').add({
      'amount':    _amount,
      'message':   _message,
      'donorName': user?.displayName ?? 'Anonyme',
      'donorId':   user?.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status':    'pending', // → 'completed' après paiement réel
    });

    setState(() { _loading = false; _success = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_success) return Scaffold(
      appBar: AppBar(title: const Text('Don effectué ✅')),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.volunteer_activism, size: 52, color: AppColors.primary),
        ),
        const SizedBox(height: 24),
        Text('Merci pour ton don de ${_amount.toStringAsFixed(0)}€ ! 🙏',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('Ton soutien aide UVDS à continuer sa mission.',
            style: TextStyle(color: AppColors.textGrey),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour'),
        ),
      ])),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Faire un don 💚')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2E8B57)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.volunteer_activism, color: Colors.white, size: 36),
              SizedBox(height: 12),
              Text('Soutenir UVDS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Ton don aide des familles et des communautés.',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          const SizedBox(height: 28),

          const Text('Choisir un montant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Montants prédéfinis
          Wrap(spacing: 10, runSpacing: 10, children: _presets.map((p) =>
            GestureDetector(
              onTap: () => setState(() => _amount = p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: _amount == p ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _amount == p ? AppColors.primary : AppColors.border,
                    width: 2,
                  ),
                ),
                child: Text('${p.toStringAsFixed(0)}€',
                    style: TextStyle(
                      color: _amount == p ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    )),
              ),
            ),
          ).toList()),

          const SizedBox(height: 16),

          // Montant personnalisé
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Autre montant (€)',
              prefixIcon: Icon(Icons.euro, color: AppColors.primary),
            ),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) setState(() => _amount = parsed);
            },
          ),

          const SizedBox(height: 20),

          const Text('Message (optionnel)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Laisse un message d\'encouragement...'),
            onChanged: (v) => _message = v,
          ),

          const SizedBox(height: 28),

          // Historique dons
          const Text('Derniers dons',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: _db.collection('donations')
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox();
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Text('Sois le premier à donner ! 💚',
                  style: TextStyle(color: AppColors.textGrey));
              return Column(children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.favorite, color: AppColors.primary, size: 18),
                  ),
                  title: Text(data['donorName'] ?? 'Anonyme',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: (data['message'] ?? '').isNotEmpty
                      ? Text(data['message']) : null,
                  trailing: Text('${data['amount']?.toStringAsFixed(0) ?? '0'}€',
                      style: const TextStyle(color: AppColors.primary,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                );
              }).toList());
            },
          ),

          const SizedBox(height: 28),

          // Bouton don
          ElevatedButton.icon(
            icon: const Icon(Icons.volunteer_activism),
            label: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Donner ${_amount.toStringAsFixed(0)}€'),
            onPressed: _loading ? null : _donate,
          ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              '🔒 Paiement sécurisé — Intégrer Stripe pour production',
              style: TextStyle(fontSize: 11, color: AppColors.textGrey),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }
}

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
