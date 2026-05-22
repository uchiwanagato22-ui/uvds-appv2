// ═══════════════════════════════════════════════════════
// UVDS WEB — Landing Page + Dashboard
// Fichier : web/lib/main.dart (projet Flutter séparé)
// OU ajoute dans le projet mobile avec flutter build web
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey:            'AIzaSyD_gmlLb6VGbuA8m93H6VjunMvbB-6fTHk',
      appId:             '1:145848279394:android:8717ec68d67e2a72f9cc3b',
      messagingSenderId: '145848279394',
      projectId:         'uvds-c316e',
      storageBucket:     'uvds-c316e.firebasestorage.app',
    ),
  );
  runApp(const UVDSWeb());
}

// ─── Couleurs ─────────────────────────
class WColors {
  static const primary  = Color(0xFF1E7A3C);
  static const dark     = Color(0xFF0A0F0A);
  static const light    = Color(0xFFF7FAF7);
  static const accent   = Color(0xFF4CAF50);
  static const textGrey = Color(0xFF6B7C6B);
}

final _webDb = FirebaseFirestore.instance;

// ═══════════════════════════════════════
// APP WEB ROOT
// ═══════════════════════════════════════
class UVDSWeb extends StatelessWidget {
  const UVDSWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UVDS — Ensemble pour un avenir meilleur',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: WColors.primary),
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (_, snap) {
          if (snap.hasData) return const WebDashboard();
          return const WebLandingPage();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════
// LANDING PAGE WEB
// ═══════════════════════════════════════
class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(children: [

          // ── NAVBAR ──────────────────
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 80 : 20, vertical: 16),
            color: Colors.white,
            child: Row(children: [
              // Logo
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                      color: WColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.balance, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Text('UVDS',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                        color: WColors.primary)),
              ]),
              const Spacer(),
              if (isDesktop) ...[
                _NavLink('Accueil'),
                _NavLink('À propos'),
                _NavLink('Projets'),
                _NavLink('Dons'),
                const SizedBox(width: 16),
              ],
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WebLoginPage())),
                child: const Text('Connexion Admin'),
              ),
            ]),
          ),

          // ── HERO ────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 80 : 24,
                vertical: isDesktop ? 100 : 60),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [WColors.primary, Color(0xFF2E8B57)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(children: [
              Text(
                'Ensemble pour un\navenir meilleur 🌿',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 56 : 32,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'UVDS — Union pour la Vie et le Développement Social\n'
                'Unité • Volonté • Développement • Solidarité',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Stats en temps réel
              Wrap(spacing: 24, runSpacing: 16, alignment: WrapAlignment.center, children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _webDb.collection('users').snapshots(),
                  builder: (_, snap) => _HeroStat(
                    '${snap.data?.docs.length ?? 0}', 'Membres'),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _webDb.collection('projects').snapshots(),
                  builder: (_, snap) => _HeroStat(
                    '${snap.data?.docs.length ?? 0}', 'Projets'),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _webDb.collection('posts').snapshots(),
                  builder: (_, snap) => _HeroStat(
                    '${snap.data?.docs.length ?? 0}', 'Publications'),
                ),
              ]),

              const SizedBox(height: 40),

              // Boutons CTA
              Wrap(spacing: 16, children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: WColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Télécharger l\'app',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {},
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('Faire un don'),
                  onPressed: () {},
                ),
              ]),
            ]),
          ),

          // ── FONCTIONNALITÉS ─────────
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 80 : 24, vertical: 80),
            color: WColors.light,
            child: Column(children: [
              const Text('Tout ce dont votre ONG a besoin',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Une plateforme complète pour gérer votre communauté',
                  style: TextStyle(color: WColors.textGrey, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 48),
              Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
                _FeatureCard(Icons.article, 'Publications',
                    'Partagez des posts, images et actualités avec vos membres'),
                _FeatureCard(Icons.chat, 'Chat temps réel',
                    'Messagerie groupe et messages privés entre membres'),
                _FeatureCard(Icons.folder, 'Gestion projets',
                    'Créez et suivez vos projets humanitaires'),
                _FeatureCard(Icons.volunteer_activism, 'Système de dons',
                    'Collectez des dons via Bankily et Masrivi'),
                _FeatureCard(Icons.admin_panel_settings, 'Panel Admin',
                    'Gérez membres, contenus et validez les dons'),
                _FeatureCard(Icons.notifications, 'Notifications',
                    'Restez informés des activités de votre ONG'),
              ]),
            ]),
          ),

          // ── DERNIERS PROJETS ────────
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 80 : 24, vertical: 80),
            child: Column(children: [
              const Text('Nos derniers projets',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 48),
              StreamBuilder<QuerySnapshot>(
                stream: _webDb.collection('projects')
                    .orderBy('createdAt', descending: true)
                    .limit(6)
                    .snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) return const CircularProgressIndicator();
                  final docs = snap.data!.docs;
                  return Wrap(spacing: 20, runSpacing: 20, children: docs.map((doc) {
                    final data   = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'En cours';
                    Color color;
                    switch (status) {
                      case 'Terminé':  color = Colors.green;  break;
                      case 'Planifié': color = Colors.blue;   break;
                      case 'Annulé':   color = Colors.red;    break;
                      default:         color = WColors.primary;
                    }
                    return Container(
                      width: isDesktop ? 280 : double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(status,
                              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Text(data['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(data['desc'] ?? '',
                            style: const TextStyle(color: WColors.textGrey, fontSize: 13),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                        Text('Par ${data['createdBy'] ?? ''}',
                            style: const TextStyle(color: WColors.textGrey, fontSize: 11)),
                      ]),
                    );
                  }).toList());
                },
              ),
            ]),
          ),

          // ── DONS ────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 80 : 24, vertical: 80),
            color: WColors.primary,
            child: Column(children: [
              const Text('Soutenez UVDS',
                  style: TextStyle(color: Colors.white, fontSize: 36,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text('Votre don aide des familles et des communautés.',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),
              Wrap(spacing: 16, children: [5, 10, 20, 50].map((amount) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text('\$$amount',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ).toList()),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text('Envoie via Bankily ou Masrivi',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Text('32652300',
                      style: TextStyle(color: Colors.white, fontSize: 36,
                          fontWeight: FontWeight.w900, letterSpacing: 4)),
                ]),
              ),
            ]),
          ),

          // ── FOOTER ──────────────────
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 80 : 24, vertical: 40),
            color: WColors.dark,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(
                      color: WColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.balance, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text('UVDS',
                    style: TextStyle(color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 12),
              const Text('Unité • Volonté • Développement • Solidarité',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('© ${DateTime.now().year} UVDS. Tous droits réservés.',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  const _NavLink(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(label, style: const TextStyle(color: WColors.textGrey, fontWeight: FontWeight.w500)),
  );
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  const _HeroStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white,
        fontSize: 36, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: Colors.white70)),
  ]);
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  const _FeatureCard(this.icon, this.title, this.desc);
  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: WColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: WColors.primary, size: 26),
      ),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 8),
      Text(desc, style: const TextStyle(color: WColors.textGrey, fontSize: 13, height: 1.5)),
    ]),
  );
}

// ═══════════════════════════════════════
// WEB LOGIN PAGE
// ═══════════════════════════════════════
class WebLoginPage extends StatefulWidget {
  const WebLoginPage({super.key});
  @override
  State<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends State<WebLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  String? _error;

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } catch (e) {
      setState(() { _error = 'Identifiants incorrects'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.light,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08), blurRadius: 24)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(color: WColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 20),
            const Text('Connexion Admin',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Accès réservé aux administrateurs',
                style: TextStyle(color: WColors.textGrey)),
            const SizedBox(height: 32),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red)),
              ),

            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: WColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Se connecter', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════
// WEB DASHBOARD ADMIN
// ═══════════════════════════════════════
class WebDashboard extends StatefulWidget {
  const WebDashboard({super.key});
  @override
  State<WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<WebDashboard> {
  int _selectedMenu = 0;
  final List<String> _menus = ['Dashboard', 'Membres', 'Posts', 'Projets', 'Dons'];
  final List<IconData> _icons = [
    Icons.dashboard, Icons.people, Icons.article, Icons.folder, Icons.payments
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.light,
      body: Row(children: [
        // ── Sidebar ──────────────────
        Container(
          width: 240,
          color: WColors.dark,
          child: Column(children: [
            // Logo
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(
                      color: WColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.balance, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text('UVDS Admin',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
            ),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 8),

            // Menu items
            ..._menus.asMap().entries.map((e) {
              final sel = _selectedMenu == e.key;
              return GestureDetector(
                onTap: () => setState(() => _selectedMenu = e.key),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? WColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(_icons[e.key],
                        color: sel ? Colors.white : Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Text(e.value,
                        style: TextStyle(
                            color: sel ? Colors.white : Colors.white54,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ]),
                ),
              );
            }),

            const Spacer(),

            // Déconnexion
            GestureDetector(
              onTap: () => FirebaseAuth.instance.signOut(),
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(children: [
                  Icon(Icons.logout, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text('Déconnexion', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),

        // ── Contenu ──────────────────
        Expanded(child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            color: Colors.white,
            child: Row(children: [
              Text(_menus[_selectedMenu],
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              StreamBuilder<DocumentSnapshot>(
                stream: _webDb.collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                builder: (_, snap) {
                  final data = snap.data?.data() as Map<String, dynamic>?;
                  final name = data?['name'] ?? 'Admin';
                  return Row(children: [
                    CircleAvatar(
                      backgroundColor: WColors.primary.withValues(alpha: 0.2),
                      child: Text(name[0].toUpperCase(),
                          style: const TextStyle(color: WColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]);
                },
              ),
            ]),
          ),

          // Contenu selon menu
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: _buildContent(),
          )),
        ])),
      ]),
    );
  }

  Widget _buildContent() {
    switch (_selectedMenu) {
      case 0: return _buildDashboard();
      case 1: return _buildMembers();
      case 2: return _buildPosts();
      case 3: return _buildProjects();
      case 4: return _buildDonations();
      default: return const SizedBox();
    }
  }

  // Dashboard
  Widget _buildDashboard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Vue d\'ensemble',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      Wrap(spacing: 20, runSpacing: 20, children: [
        _WebStatCard('Membres',     Icons.people,           Colors.blue,
            _webDb.collection('users').snapshots()),
        _WebStatCard('Posts',       Icons.article,          Colors.green,
            _webDb.collection('posts').snapshots()),
        _WebStatCard('Projets',     Icons.folder,           Colors.purple,
            _webDb.collection('projects').snapshots()),
        _WebStatCard('Dons',        Icons.volunteer_activism, Colors.orange,
            _webDb.collection('donations').snapshots()),
      ]),
      const SizedBox(height: 32),

      // Dons en attente
      const Text('Dons en attente de validation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      StreamBuilder<QuerySnapshot>(
        stream: _webDb.collection('donations')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Text('Aucun don en attente ✅');
          return Column(children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Text(data['badge'] ?? '❤️',
                    style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['donorName'] ?? 'Anonyme',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${data['tier']} — ${data['paymentMethod']} — Réf: ${data['reference'] ?? 'N/A'}',
                      style: const TextStyle(color: WColors.textGrey, fontSize: 12)),
                ])),
                Text('\$${data['amount']}',
                    style: const TextStyle(color: WColors.primary,
                        fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: WColors.primary),
                  onPressed: () async {
                    await doc.reference.update({'status': 'confirmed'});
                    if (data['donorId'] != null) {
                      await _webDb.collection('users').doc(data['donorId']).update({
                        'tier': data['tier'], 'badge': data['badge'],
                        if (data['tier'] == 'Gold') 'role': 'admin',
                      });
                      await _webDb.collection('notifications').add({
                        'uid':     data['donorId'],
                        'message': '🎉 Ton don ${data['badge']} a été validé !',
                        'read':    false,
                        'time':    FieldValue.serverTimestamp(),
                      });
                    }
                  },
                  child: const Text('Valider', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  onPressed: () => doc.reference.update({'status': 'rejected'}),
                  child: const Text('Rejeter', style: TextStyle(color: Colors.red)),
                ),
              ]),
            );
          }).toList());
        },
      ),
    ]);
  }

  // Membres
  Widget _buildMembers() {
    return StreamBuilder<QuerySnapshot>(
      stream: _webDb.collection('users').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        return Column(children: snap.data!.docs.map((doc) {
          final data    = doc.data() as Map<String, dynamic>;
          final role    = data['role'] ?? 'membre';
          final isAdmin = role == 'admin';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: WColors.primary.withValues(alpha: 0.2),
                child: Text((data['name'] ?? 'M')[0].toUpperCase(),
                    style: const TextStyle(color: WColors.primary, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(data['email'] ?? '', style: const TextStyle(color: WColors.textGrey)),
              ])),
              Text(data['badge'] ?? '', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.orange.shade50 : WColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role.toUpperCase(),
                    style: TextStyle(
                        color: isAdmin ? Colors.orange : WColors.primary,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              if (!isAdmin) TextButton(
                onPressed: () => _webDb.collection('users').doc(doc.id).update({'role': 'admin'}),
                child: const Text('→ Admin'),
              ),
            ]),
          );
        }).toList());
      },
    );
  }

  // Posts
  Widget _buildPosts() {
    return StreamBuilder<QuerySnapshot>(
      stream: _webDb.collection('posts').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        return Column(children: snap.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['authorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(data['text'] ?? '',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WColors.textGrey)),
              ])),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _webDb.collection('posts').doc(doc.id).delete(),
              ),
            ]),
          );
        }).toList());
      },
    );
  }

  // Projets
  Widget _buildProjects() {
    return StreamBuilder<QuerySnapshot>(
      stream: _webDb.collection('projects').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        return Column(children: snap.data!.docs.map((doc) {
          final data   = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'En cours';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(data['desc'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: WColors.textGrey)),
                Text('Par ${data['createdBy'] ?? ''}',
                    style: const TextStyle(color: WColors.textGrey, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: WColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(status,
                    style: const TextStyle(color: WColors.primary, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _webDb.collection('projects').doc(doc.id).delete(),
              ),
            ]),
          );
        }).toList());
      },
    );
  }

  // Dons
  Widget _buildDonations() {
    return StreamBuilder<QuerySnapshot>(
      stream: _webDb.collection('donations')
          .orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const CircularProgressIndicator();
        double total = 0;
        for (final doc in snap.data!.docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['status'] == 'confirmed') {
            total += (d['amount'] as num?)?.toDouble() ?? 0;
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [WColors.primary, Color(0xFF2E8B57)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('\$${total.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.w900)),
                const Text('Total dons confirmés',
                    style: TextStyle(color: Colors.white70)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          ...snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isPending = data['status'] == 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPending ? Colors.orange.shade50 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isPending ? Colors.orange.shade200 : Colors.grey.shade200),
              ),
              child: Row(children: [
                Text(data['badge'] ?? '❤️', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['donorName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${data['tier']} — ${data['paymentMethod']}',
                      style: const TextStyle(color: WColors.textGrey, fontSize: 12)),
                  if ((data['reference'] ?? '').isNotEmpty)
                    Text('Réf: ${data['reference']}',
                        style: const TextStyle(color: WColors.textGrey, fontSize: 11)),
                ])),
                Text('\$${data['amount']}',
                    style: const TextStyle(color: WColors.primary,
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? '⏳ En attente' : '✅ Confirmé',
                    style: TextStyle(
                        color: isPending ? Colors.orange : Colors.green,
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: WColors.primary),
                    onPressed: () async {
                      await doc.reference.update({'status': 'confirmed'});
                      if (data['donorId'] != null) {
                        await _webDb.collection('users').doc(data['donorId']).update({
                          'tier': data['tier'], 'badge': data['badge'],
                          if (data['tier'] == 'Gold') 'role': 'admin',
                        });
                        await _webDb.collection('notifications').add({
                          'uid':     data['donorId'],
                          'message': '🎉 Ton don ${data['badge']} a été validé !',
                          'read':    false, 'time': FieldValue.serverTimestamp(),
                        });
                      }
                    },
                    child: const Text('Valider', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ]),
            );
          }),
        ]);
      },
    );
  }
}

class _WebStatCard extends StatelessWidget {
  final String label; final IconData icon;
  final Color color; final Stream<QuerySnapshot> stream;
  const _WebStatCard(this.label, this.icon, this.color, this.stream);

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: stream,
    builder: (_, snap) => Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 12),
        Text('${snap.data?.docs.length ?? 0}',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(color: WColors.textGrey)),
      ]),
    ),
  );
}
