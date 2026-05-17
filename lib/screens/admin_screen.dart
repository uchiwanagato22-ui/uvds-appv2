import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import '../services/donation_service.dart';

final _adminDb = FirebaseFirestore.instance;

// ═══════════════════════════════════════
// ADMIN SCREEN — Panel complet
// Accès : role == admin OU tier == Gold
// ═══════════════════════════════════════
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade700,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.admin_panel_settings, size: 22),
          SizedBox(width: 8),
          Text("Panel Admin"),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Dashboard"),
            Tab(icon: Icon(Icons.people),    text: "Membres"),
            Tab(icon: Icon(Icons.article),   text: "Modération"),
            Tab(icon: Icon(Icons.payments),  text: "Dons"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _DashboardTab(),
          _MembersTab(),
          _ModerationTab(),
          _DonationsTab(),
        ],
      ),
    );
  }
}

// ─── Dashboard ────────────────────────
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text("Vue globale",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),

      // Stats grid
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _StatTile("Membres",     Icons.people,           Colors.blue,
              _adminDb.collection("users").snapshots()),
          _StatTile("Posts",       Icons.article,          Colors.green,
              _adminDb.collection("posts").snapshots()),
          _StatTile("Projets",     Icons.folder,           Colors.purple,
              _adminDb.collection("projects").snapshots()),
          _StatTile("Dons",        Icons.volunteer_activism, Colors.orange,
              _adminDb.collection("donations").snapshots()),
        ],
      ),

      const SizedBox(height: 24),

      // Total dons
      StreamBuilder<QuerySnapshot>(
        stream: _adminDb.collection("donations")
            .where("status", isEqualTo: "pending").snapshots(),
        builder: (_, snap) {
          double total = 0;
          for (final doc in (snap.data?.docs ?? [])) {
            final d = doc.data() as Map<String, dynamic>;
            total += (d["amount"] as num?)?.toDouble() ?? 0;
          }
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF2E8B57)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 36),
              const SizedBox(height: 8),
              Text("\$${total.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.white,
                      fontSize: 36, fontWeight: FontWeight.w900)),
              const Text("Total dons en attente",
                  style: TextStyle(color: Colors.white70)),
            ]),
          );
        },
      ),

      const SizedBox(height: 20),

      // Activité récente
      const Text("Activité récente",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),

      StreamBuilder<QuerySnapshot>(
        stream: _adminDb.collection("posts")
            .orderBy("createdAt", descending: true).limit(5).snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return Column(children: snap.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.article, color: AppColors.primary),
              title: Text(d["authorName"] ?? "Membre",
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(d["text"] ?? "",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList());
        },
      ),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;
  const _StatTile(this.label, this.icon, this.color, this.stream);

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
        Text("${snap.data?.docs.length ?? 0}",
            style: TextStyle(fontSize: 26,
                fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ]),
    ),
  );
}

// ─── Membres Tab ──────────────────────
class _MembersTab extends StatelessWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminDb.collection("users")
          .orderBy("createdAt", descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data    = docs[i].data() as Map<String, dynamic>;
            final role    = data["role"] ?? "membre";
            final name    = data["name"] ?? "Membre";
            final email   = data["email"] ?? "";
            final badge   = data["tier"] ?? "";
            final banned  = data["banned"] ?? false;
            final isAdmin = role == "admin";

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Stack(children: [
                  CircleAvatar(
                    backgroundColor: banned
                        ? Colors.red.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.2),
                    child: Text(name[0].toUpperCase(),
                        style: TextStyle(
                            color: banned ? Colors.red : AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (badge.isNotEmpty)
                    Positioned(right: 0, bottom: 0,
                        child: Text(badge, style: const TextStyle(fontSize: 10))),
                ]),
                title: Text(name,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: banned ? Colors.red : null)),
                subtitle: Text(email),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    final ref = _adminDb.collection("users").doc(docs[i].id);
                    switch (v) {
                      case "admin":
                        await ref.update({"role": "admin"});
                        break;
                      case "membre":
                        await ref.update({"role": "membre"});
                        break;
                      case "ban":
                        await ref.update({"banned": true});
                        break;
                      case "unban":
                        await ref.update({"banned": false});
                        break;
                      case "gold":
                        await ref.update({"tier": "Gold", "role": "admin"});
                        break;
                      case "delete":
                        showDialog(context: context, builder: (_) => AlertDialog(
                          title: const Text("Supprimer ?"),
                          content: Text("Supprimer $name définitivement ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context),
                                child: const Text("Annuler")),
                            TextButton(
                              onPressed: () {
                                ref.delete();
                                Navigator.pop(context);
                              },
                              child: const Text("Supprimer",
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ));
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!isAdmin)
                      const PopupMenuItem(value: "admin",
                          child: Text("🛡 Passer Admin")),
                    if (isAdmin)
                      const PopupMenuItem(value: "membre",
                          child: Text("👤 Rétrograder Membre")),
                    const PopupMenuItem(value: "gold",
                        child: Text("🥇 Donner Gold")),
                    if (!banned)
                      const PopupMenuItem(value: "ban",
                          child: Text("🚫 Bannir", style: TextStyle(color: Colors.orange))),
                    if (banned)
                      const PopupMenuItem(value: "unban",
                          child: Text("✅ Débannir")),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: "delete",
                        child: Text("🗑 Supprimer",
                            style: TextStyle(color: Colors.red))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? Colors.orange.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(role.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            color: isAdmin ? Colors.orange : AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Modération Tab ───────────────────
class _ModerationTab extends StatefulWidget {
  const _ModerationTab();
  @override
  State<_ModerationTab> createState() => _ModerationTabState();
}

class _ModerationTabState extends State<_ModerationTab> {
  String _filter = "Posts";

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filtre
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: ["Posts", "Projets"].map((f) =>
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _filter == f ? Colors.orange.shade700 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(f, style: TextStyle(
                    color: _filter == f ? Colors.white : AppColors.textDark,
                    fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ).toList()),
      ),

      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: _adminDb.collection(
            _filter == "Posts" ? "posts" : "projects")
            .orderBy(_filter == "Posts" ? "createdAt" : "createdAt",
                descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(
            child: Text("Aucun $_filter",
                style: const TextStyle(color: AppColors.textGrey)),
          );
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final col  = _filter == "Posts" ? "posts" : "projects";
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    _filter == "Posts"
                        ? (data["authorName"] ?? "Membre")
                        : (data["title"] ?? "Projet"),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    _filter == "Posts"
                        ? (data["text"] ?? "")
                        : (data["desc"] ?? ""),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // Épingler (posts seulement)
                    if (_filter == "Posts")
                      IconButton(
                        icon: Icon(
                          (data["pinned"] ?? false)
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: AppColors.primary,
                        ),
                        onPressed: () => _adminDb.collection(col)
                            .doc(docs[i].id)
                            .update({"pinned": !(data["pinned"] ?? false)}),
                      ),
                    // Supprimer
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Supprimer ?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context),
                                child: const Text("Annuler")),
                            TextButton(
                              onPressed: () {
                                _adminDb.collection(col).doc(docs[i].id).delete();
                                Navigator.pop(context);
                              },
                              child: const Text("Supprimer",
                                  style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      )),
    ]);
  }
}

// ─── Dons Tab ─────────────────────────
class _DonationsTab extends StatefulWidget {
  const _DonationsTab();
  @override
  State<_DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<_DonationsTab> {
  String _filter = "pending";

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filtre
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: {
          "pending":   "⏳ En attente",
          "confirmed": "✅ Confirmés",
          "rejected":  "❌ Rejetés",
        }.entries.map((e) =>
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _filter == e.key
                      ? Colors.orange.shade700
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(e.value, style: TextStyle(
                    color: _filter == e.key ? Colors.white : AppColors.textDark,
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ).toList()),
      ),

      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: _adminDb.collection("donations")
            .where("status", isEqualTo: _filter)
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return Center(
            child: Text("Aucun don $_filter",
                style: const TextStyle(color: AppColors.textGrey)),
          );
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data   = docs[i].data() as Map<String, dynamic>;
              final isPending = _filter == "pending";
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(data["badge"] ?? "❤️",
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data["donorName"] ?? "Anonyme",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text("${data["tier"] ?? ""} — ${data["paymentMethod"] ?? ""}",
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          ],
                        )),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              data["amountMru"] != null
                                  ? '${formatMru((data["amountMru"] as num).toInt())} MRU'
                                  : mruPaymentLabel(
                                      (data["amount"] as num?) ?? 0),
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20),
                            ),
                            Text(
                              usdWithMru((data["amount"] as num?) ?? 0),
                              style: const TextStyle(
                                  color: AppColors.textGrey, fontSize: 11),
                            ),
                          ],
                        ),
                      ]),

                      if ((data["reference"] ?? "").isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(children: [
                            const Icon(Icons.receipt, size: 14, color: AppColors.textGrey),
                            const SizedBox(width: 8),
                            Text("Réf: ${data["reference"]}",
                                style: const TextStyle(fontSize: 13)),
                          ]),
                        ),
                      ],

                      if ((data["message"] ?? "").isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("💬 ${data["message"]}",
                            style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      ],

                      if (isPending) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  minimumSize: const Size(0, 42)),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text("Valider"),
                              onPressed: () async {
                                // Confirmer le don + donner le badge
                                await _adminDb.collection("donations")
                                    .doc(docs[i].id)
                                    .update({"status": "confirmed"});
                                // Mettre à jour le profil du donateur
                                final donorId = data["donorId"] as String?;
                                if (donorId != null && donorId.isNotEmpty) {
                                  final displayTier =
                                      data["tier"] as String? ?? "";
                                  final tierKey =
                                      DonationService.donationTierKeyFromDisplay(
                                          displayTier);
                                  final amount =
                                      (data["amount"] as num?)?.toDouble() ?? 0;
                                  final updates = <String, dynamic>{
                                    "tier": displayTier,
                                    "badge": data["badge"],
                                    "donationTier": tierKey,
                                    "pendingBadge": FieldValue.delete(),
                                    "pendingTier": FieldValue.delete(),
                                    "pendingDonRef": FieldValue.delete(),
                                    "totalDonated": FieldValue.increment(amount),
                                    "lastDonationAt":
                                        FieldValue.serverTimestamp(),
                                  };
                                  if (displayTier == "Gold") {
                                    updates["role"] = "admin";
                                  }
                                  await _adminDb
                                      .collection("users")
                                      .doc(donorId)
                                      .update(updates);
                                  // Notifier le donateur
                                  await _adminDb.collection("notifications").add({
                                    "uid":     data["donorId"],
                                    "message": "🎉 Ton don ${data['badge']} a été validé ! Merci pour ton soutien !",
                                    "read":    false,
                                    "time":    FieldValue.serverTimestamp(),
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red),
                                  minimumSize: const Size(0, 42)),
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              label: const Text("Rejeter",
                                  style: TextStyle(color: Colors.red)),
                              onPressed: () async {
                                await _adminDb.collection("donations")
                                    .doc(docs[i].id)
                                    .update({"status": "rejected"});
                                if (data["donorId"] != null) {
                                  await _adminDb.collection("notifications").add({
                                    "uid":     data["donorId"],
                                    "message": "❌ Ton don a été rejeté. Contacte l'admin.",
                                    "read":    false,
                                    "time":    FieldValue.serverTimestamp(),
                                  });
                                }
                              },
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      )),
    ]);
  }
}
