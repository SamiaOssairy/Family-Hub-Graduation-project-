import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- Data Models ---
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

// Changed to StatefulWidget so we can update the lists when you click "Add"
class FamilyDashboardScreen extends StatefulWidget {
  const FamilyDashboardScreen({super.key});

  @override
  State<FamilyDashboardScreen> createState() => _FamilyDashboardScreenState();
}

class _FamilyDashboardScreenState extends State<FamilyDashboardScreen> {
  // --- Controllers for Input Fields ---
  final _annTitleCtrl = TextEditingController();
  final _annContentCtrl = TextEditingController();
  final _eventTitleCtrl = TextEditingController();
  final _eventDescCtrl = TextEditingController();

  // --- Dynamic Lists ---
  final List<Announcement> _announcements = []; 
  
  final List<FamilyEvent> _events = [
    // One default event to start
    FamilyEvent(
      title: 'Pool Party', 
      description: 'Don\'t forget sunscreen!', 
      imageUrl: 'https://picsum.photos/seed/pool/300/200' 
    ),
  ];

  @override
  void dispose() {
    _annTitleCtrl.dispose();
    _annContentCtrl.dispose();
    _eventTitleCtrl.dispose();
    _eventDescCtrl.dispose();
    super.dispose();
  }

  // --- Logic: Add Announcement ---
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

  // --- Logic: Add Event ---
  void _addEvent() {
    if (_eventTitleCtrl.text.isNotEmpty) {
      // Use current time to create a unique random image
      String randomId = DateTime.now().millisecondsSinceEpoch.toString();
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

  // --- Logic: Show Modals ---
  void _showAnnouncementModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Announcement', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _annTitleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 10),
            TextField(controller: _annContentCtrl, decoration: const InputDecoration(labelText: 'Message')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _addAnnouncement, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Post')
          ),
        ],
      ),
    );
  }

  void _showEventModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Event', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _eventTitleCtrl, decoration: const InputDecoration(labelText: 'Event Name')),
            const SizedBox(height: 10),
            TextField(controller: _eventDescCtrl, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _addEvent, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Create')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mahmoud Family', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Chilling', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Colors.green[700]),
                      const SizedBox(width: 16),
                      Icon(Icons.notifications_none, color: Colors.green[700]),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 30),

              // 2. Categories Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Categories', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF2E3E33))),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(value: false, onChanged: (v) {}, activeThumbColor: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Grid Menu
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                childAspectRatio: 1.0,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                children: [
                  _buildMenuCard(context, 'Tasks', Icons.task_alt, '/tasks', badgeCount: 1),
                  _buildMenuCard(context, 'Status', Icons.people_outline, '/status'),
                  _buildMenuCard(context, 'Leadership', Icons.leaderboard_outlined, null),
                  _buildMenuCard(context, 'Rewards', Icons.stars_outlined, '/rewards'),
                  _buildMenuCard(context, 'Tracking', Icons.location_on_outlined, null),
                  _buildMenuCard(context, 'Planning', Icons.calendar_today_outlined, null),
                  _buildMenuCard(context, 'Budgeting', Icons.account_balance_wallet_outlined, null),
                  _buildMenuCard(context, 'Recipes', Icons.restaurant_menu, null),
                ],
              ),
              const SizedBox(height: 30),

              // 4. Announcements Section (UPDATED)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Announcements', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF2E3E33))),
                  // ADD BUTTON
                  InkWell(
                    onTap: _showAnnouncementModal,
                    child: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8E6C9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: _announcements.isEmpty 
                  ? Center(
                      child: Text(
                        "No new announcements",
                        style: GoogleFonts.poppins(color: Colors.green[800], fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _announcements.length,
                      separatorBuilder: (ctx, i) => const Divider(color: Colors.white54, height: 10),
                      itemBuilder: (context, index) {
                         return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(_announcements[index].title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green[900])),
                             Text(_announcements[index].content, style: GoogleFonts.poppins(fontSize: 12, color: Colors.green[800])),
                           ],
                         );
                      },
                    ),
              ),
              const SizedBox(height: 30),

              // 5. Family Events (UPDATED)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Family Events', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF2E3E33))),
                  // ADD BUTTON
                  InkWell(
                    onTap: _showEventModal,
                    child: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return Row(
                      children: [
                        _buildEventCard(event),
                        const SizedBox(width: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 1,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) Navigator.pushReplacementNamed(context, '/home');
          if (index == 4) Navigator.pushReplacementNamed(context, '/settings');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, String? routeName, {int? badgeCount}) {
    return GestureDetector(
      onTap: () {
        if (routeName != null) {
          Navigator.pushNamed(context, routeName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title feature coming soon!')));
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F6EF),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFA5D6A7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green[800]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (badgeCount != null)
                    Positioned(
                      top: -6,
                      left: -6,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.green[700], shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4)]),
                        child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated to support Network Image with Text Overlay
  Widget _buildEventCard(FamilyEvent event) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(14),
        image: DecorationImage(
          image: NetworkImage(event.imageUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken), // Darken for readability
        ),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title, 
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              event.description, 
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
