import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

// ── Data Models (unchanged) ───────────────────────────────────────────────────

class Announcement {
  String title;
  String content;
  Announcement({required this.title, required this.content});
}

class FamilyEvent {
  String title;
  String description;
  String imageUrl;
  FamilyEvent({required this.title, required this.description, required this.imageUrl});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onLogout;
  const DashboardScreen({super.key, this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Controllers (unchanged) ───────────────────
  final _annTitleCtrl    = TextEditingController();
  final _annContentCtrl  = TextEditingController();
  final _eventTitleCtrl  = TextEditingController();
  final _eventDescCtrl   = TextEditingController();

  // ── Data (unchanged) ─────────────────────────
  final List<Announcement> _announcements = [];
  final List<FamilyEvent> _events = [
    FamilyEvent(
      title: 'Family Game Night',
      description: 'Every Friday at 7 PM!',
      imageUrl: 'https://picsum.photos/seed/game/300/200',
    ),
  ];

  // ── UI State ─────────────────────────────────
  bool _editMode = false;
  int  _activeTab = 1; // Dashboard is active

  @override
  void dispose() {
    _annTitleCtrl.dispose();
    _annContentCtrl.dispose();
    _eventTitleCtrl.dispose();
    _eventDescCtrl.dispose();
    super.dispose();
  }

  // ── Scaling helper (matches home.dart) ────────
  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  // ── Logic: Add Announcement (unchanged) ───────
  void _addAnnouncement() {
    if (_annTitleCtrl.text.isNotEmpty) {
      setState(() {
        _announcements.insert(0, Announcement(
          title: _annTitleCtrl.text,
          content: _annContentCtrl.text,
        ));
      });
      _annTitleCtrl.clear();
      _annContentCtrl.clear();
      Navigator.pop(context);
    }
  }

  // ── Logic: Add Event (unchanged) ─────────────
  void _addEvent() {
    if (_eventTitleCtrl.text.isNotEmpty) {
      final randomId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() {
        _events.add(FamilyEvent(
          title: _eventTitleCtrl.text,
          description: _eventDescCtrl.text,
          imageUrl: 'https://picsum.photos/seed/$randomId/300/200',
        ));
      });
      _eventTitleCtrl.clear();
      _eventDescCtrl.clear();
      Navigator.pop(context);
    }
  }

  // ── Logic: Show Announcement Modal (unchanged) ─
  void _showAnnouncementModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Announcement', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _annTitleCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _annContentCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _addAnnouncement,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Logic: Show Event Modal (unchanged) ───────
  void _showEventModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _eventTitleCtrl,
              decoration: InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventDescCtrl,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _addEvent,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Module config ──────────────────────────────────────────────────────────
  static const _modules = [
    {'label': 'Tasks',      'icon': Icons.checklist_rounded,            'route': '/tasks',                'bg': Color(0xFFE0F2F1), 'fg': Color(0xFF00897B)},
    {'label': 'Budget',     'icon': Icons.account_balance_wallet_outlined,'route': '/budget',              'bg': Color(0xFFE8F5F5), 'fg': Color(0xFF00897B)},
    {'label': 'Events',     'icon': Icons.event_outlined,                 'route': '/future-events',       'bg': Color(0xFFFFF3E0), 'fg': Color(0xFFE65100)},
    {'label': 'Wallet',     'icon': Icons.credit_card_outlined,           'route': '/combined-wallet',     'bg': Color(0xFFE0F2F1), 'fg': Color(0xFF00695C)},
    {'label': 'Rewards',    'icon': Icons.emoji_events_outlined,        'route': '/rewards',              'bg': Color(0xFFFFF8E1), 'fg': Color(0xFFF9A825)},
    {'label': 'Redeem',     'icon': Icons.card_giftcard_outlined,       'route': '/redeem',               'bg': Color(0xFFFCE4EC), 'fg': Color(0xFFAD1457)},
    {'label': 'Status',     'icon': Icons.trending_up_rounded,          'route': '/status',               'bg': Color(0xFFE3F2FD), 'fg': Color(0xFF1565C0)},
    {'label': 'Points',     'icon': Icons.stars_rounded,                'route': '/family-points',        'bg': Color(0xFFFCE4EC), 'fg': Color(0xFFAD1457)},
    {'label': 'Food Hub',   'icon': Icons.restaurant_outlined,          'route': '/food-hub',             'bg': Color(0xFFFFF3E0), 'fg': Color(0xFFE65100)},
    {'label': 'Inventory',  'icon': Icons.inventory_2_outlined,         'route': '/inventory',            'bg': Color(0xFFEDE7F6), 'fg': Color(0xFF6A1B9A)},
    {'label': 'Recipes',    'icon': Icons.menu_book_outlined,           'route': '/recipes',              'bg': Color(0xFFE8F5F5), 'fg': Color(0xFF00897B)},
    {'label': 'Meals',      'icon': Icons.restaurant_menu_outlined,     'route': '/meals',                'bg': Color(0xFFE0F7FA), 'fg': Color(0xFF00838F)},
    {'label': 'Leftovers',  'icon': Icons.takeout_dining_outlined,      'route': '/leftovers',            'bg': Color(0xFFFBE9E7), 'fg': Color(0xFFBF360C)},
    {'label': 'Receipts',   'icon': Icons.receipt_long_outlined,        'route': '/receipts',             'bg': Color(0xFFE8EAF6), 'fg': Color(0xFF283593)},
    {'label': 'Groceries',  'icon': Icons.local_grocery_store_outlined, 'route': '/groceries',            'bg': Color(0xFFE0F2F1), 'fg': Color(0xFF00695C)},
    {'label': 'Categories', 'icon': Icons.category_outlined,            'route': '/inventory-categories', 'bg': Color(0xFFF3E5F5), 'fg': Color(0xFF7B1FA2)},
  ];

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildModulesSection(),
                        const SizedBox(height: 20),
                        _buildAnnouncementsSection(),
                        const SizedBox(height: 20),
                        _buildEventsSection(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          child: Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 19))),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Family Dashboard',
                  style: GoogleFonts.poppins(
                      fontSize: _sp(16), fontWeight: FontWeight.w700, color: AppColors.textDark)),
              Text('Manage your family activities',
                  style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.secondary)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: () {},
            icon: Icon(Icons.notifications_outlined, size: 22, color: AppColors.primary),
            tooltip: 'Notifications',
          ),
        ),
      ],
    );
  }

  // ── Modules (Categories) Section ─────────────────────────────────────────

  Widget _buildModulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('CATEGORIES',
                style: GoogleFonts.poppins(
                    fontSize: _sp(10), fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: AppColors.secondary)),
            const Spacer(),
            // Edit Mode toggle
            Text('Edit Mode',
                style: GoogleFonts.poppins(
                    fontSize: _sp(11), fontWeight: FontWeight.w600, color: AppColors.secondary)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => setState(() => _editMode = !_editMode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 20,
                decoration: BoxDecoration(
                  color: _editMode ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: _editMode ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.6,
          ),
          itemCount: _modules.length,
          itemBuilder: (context, i) {
            final m = _modules[i];
            return _buildMenuCard(
              context,
              m['label'] as String,
              m['icon'] as IconData,
              m['route'] as String,
              iconBg: m['bg'] as Color,
              iconColor: m['fg'] as Color,
            );
          },
        ),
      ],
    );
  }

  // ── Module Card ───────────────────────────────────────────────────────────

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    String? routeName, {
    Color? iconBg,
    Color? iconColor,
    int? badge,
  }) {
    iconBg ??= AppColors.primarySurface;
    iconColor ??= AppColors.primary;
    return GestureDetector(
      onTap: () {
        if (routeName != null) Navigator.pushNamed(context, routeName);
      },
      child: Container(
        decoration: AppDecorations.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$badge',
                          style: GoogleFonts.poppins(
                              fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                    fontSize: _sp(12), fontWeight: FontWeight.w600, color: AppColors.textDark),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_editMode)
              Icon(Icons.drag_handle, size: 16, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }

  // ── Announcements Section ─────────────────────────────────────────────────

  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ANNOUNCEMENTS',
                style: GoogleFonts.poppins(
                    fontSize: _sp(10), fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: AppColors.secondary)),
            const Spacer(),
            GestureDetector(
              onTap: _showAnnouncementModal,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, size: 16, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _announcements.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.card,
                child: Row(
                  children: [
                    Icon(Icons.campaign_outlined, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'No announcements yet. Tap + to add one!',
                      style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.secondary),
                    ),
                  ],
                ),
              )
            : Column(
                children: _announcements.map((ann) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: AppDecorations.card,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.campaign_outlined,
                              color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ann.title,
                                  style: GoogleFonts.poppins(
                                      fontSize: _sp(12),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark)),
                              if (ann.content.isNotEmpty)
                                Text(ann.content,
                                    style: GoogleFonts.poppins(
                                        fontSize: _sp(10), color: AppColors.secondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  // ── Family Events Section ─────────────────────────────────────────────────

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('FAMILY EVENTS',
                style: GoogleFonts.poppins(
                    fontSize: _sp(10), fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: AppColors.secondary)),
            const Spacer(),
            GestureDetector(
              onTap: _showEventModal,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add, size: 16, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _buildEventCard(_events[index]),
          ),
        ),
      ],
    );
  }

  // ── Event Card ────────────────────────────────────────────────────────────

  Widget _buildEventCard(FamilyEvent event) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        image: DecorationImage(
          image: NetworkImage(event.imageUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            AppColors.textDark.withValues(alpha: 0.45),
            BlendMode.darken,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: GoogleFonts.poppins(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: _sp(12)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              event.description,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: _sp(10)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Nav (matches home.dart exactly) ────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, '🏠', 'Home'),
              _buildNavItem(1, '⊞', 'Dashboard'),
              _buildNavItem(2, '🤖', 'AI Chat'),
              _buildNavItem(3, '📍', 'Location'),
              _buildNavItem(4, '⚙️', 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String emoji, String label) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case 1:
            setState(() => _activeTab = 1);
            break;
          case 2:
            Navigator.pushNamed(context, '/planning-chat');
            break;
          case 3:
            Navigator.pushNamed(context, '/family-map');
            break;
          case 4:
            Navigator.pushNamed(context, '/settings');
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primarySurface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: _sp(10),
              color: isActive ? AppColors.primary : const Color(0xFF9E9E9E),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
