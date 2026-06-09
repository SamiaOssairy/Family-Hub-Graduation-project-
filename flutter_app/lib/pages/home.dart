import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/models/member_model.dart';
import '../core/localization/app_i18n.dart';
import '../core/theme/app_theme.dart';
import 'setting.dart';
import 'signup_login.dart';
import 'manage_accounts_page.dart';
import '../core/widgets/guarded_button.dart';
import 'package:provider/provider.dart';
import '../core/theme/theme_provider.dart';

class HomePage extends StatefulWidget {
  final String? userName;
  final String? familyTitle;
  final VoidCallback? onLogout;

  const HomePage({
    super.key,
    this.userName,
    this.familyTitle,
    this.onLogout,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  // Scales a base size (designed at 390 px wide) to the actual screen width.
  // Capped at 480 px so desktop text doesn't grow huge.
  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  int _activeTab = 0;
  bool _locationSharing = true;

  static final _avatarColors = [
    Color(0xFF1565C0), Color(0xFF6A1B9A), Color(0xFFAD1457),
    Color(0xFFE65100), AppColors.dark, AppColors.primary,
  ];
  static final _avatarBgs = [
    Color(0xFFE3F2FD), Color(0xFFF3E5F5), Color(0xFFFCE4EC),
    Color(0xFFFFF3E0), AppColors.primarySurface, AppColors.background,
  ];
  bool _protectionSetting = false;
  List<Member> _familyMembers = [];
  String _familyTitle = '';
  String _userName = '';
  List<Map<String, dynamic>> _savedProfiles = [];
  String _activeProfileKey = '';
  bool _hasActiveProfile = false;
  bool _loading = true;
  bool _walletLoading = true;
  Map<String, dynamic> _walletSummary = {};
  List<dynamic> _recentTasks = [];
  bool _tasksLoading = true;
  List<dynamic> _futureEvents = [];
  bool _eventsLoading = true;
  List<dynamic> _pointsRanking = [];
  bool _rankingLoading = true;
  List<dynamic> _upcomingBirthdays = [];
  bool _birthdaysLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSavedProfiles();
    _fetchFamilyMembers();
    _loadWalletSummary();
    _fetchRecentTasks();
    _fetchFutureEvents();
    _fetchPointsRanking();
    _fetchUpcomingBirthdays();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('username') ?? widget.userName ?? '';
    final familyTitle = prefs.getString('familyTitle') ?? widget.familyTitle ?? '';
    final activeProfileKey = prefs.getString('activeProfileKey') ?? '';

    setState(() {
      _userName = userName;
      _familyTitle = familyTitle;
      _activeProfileKey = activeProfileKey;
      _hasActiveProfile = activeProfileKey.isNotEmpty;
    });
  }

  Future<void> _loadSavedProfiles() async {
    final profiles = await _apiService.getSavedProfiles();
    if (!mounted) return;
    setState(() {
      _savedProfiles = profiles;
    });
  }

  Future<void> _loadWalletSummary() async {
    try {
      final summary = await _apiService.getCombinedBalance();
      if (!mounted) return;
      setState(() {
        _walletSummary = summary;
        _walletLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _walletSummary = {};
        _walletLoading = false;
      });
    }
  }

  Future<void> _fetchRecentTasks() async {
    try {
      final tasks = await _apiService.getAllAssignedTasks();
      if (!mounted) return;
      setState(() {
        _recentTasks = tasks;
        _tasksLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _tasksLoading = false);
    }
  }

  Future<void> _fetchFutureEvents() async {
    try {
      final events = await _apiService.getFutureEvents();
      if (!mounted) return;
      setState(() {
        _futureEvents = events;
        _eventsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _eventsLoading = false);
    }
  }

  Future<void> _fetchPointsRanking() async {
    try {
      final ranking = await _apiService.getPointsRanking();
      if (!mounted) return;
      setState(() {
        _pointsRanking = ranking;
        _rankingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rankingLoading = false);
    }
  }

  Future<void> _fetchUpcomingBirthdays() async {
    try {
      final birthdays = await _apiService.getUpcomingBirthdays(days: 30);
      if (!mounted) return;
      setState(() {
        _upcomingBirthdays = birthdays;
        _birthdaysLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _birthdaysLoading = false);
    }
  }

  // Returns a member's display name from their email using the loaded members list.
  String _getMemberName(String mail) {
    for (final m in _familyMembers) {
      if (m.mail == mail) return m.username;
    }
    return mail.split('@').first;
  }

  Future<void> _switchProfileFromHome(String profileKey) async {
    try {
      await _apiService.switchProfile(profileKey);
      await _loadUserData();
      await _loadSavedProfiles();
      await _fetchFamilyMembers();
      await _loadWalletSummary();
      await _fetchRecentTasks();
      await _fetchFutureEvents();
      await _fetchPointsRanking();
      await _fetchUpcomingBirthdays();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Switched account', 'تم تبديل الحساب'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Failed to switch account', 'فشل تبديل الحساب')}: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAccountSwitcherSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _t('Accounts', 'الحسابات'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_savedProfiles.isNotEmpty)
                  Builder(builder: (_) {
                    Map<String, dynamic>? active;
                    for (final p in _savedProfiles) {
                      if (p['profileKey']?.toString() == _activeProfileKey) {
                        active = p;
                        break;
                      }
                    }

                    if (active == null) return const SizedBox.shrink();

                    final activeFamily = active['familyTitle']?.toString() ?? _t('Family', 'العائلة');
                    final activeUser = active['username']?.toString() ?? _t('Member', 'عضو');
                    final activeMail = active['mail']?.toString() ?? '';
                    final initial = (activeUser.isNotEmpty ? activeUser[0] : 'A').toUpperCase();

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3FAF2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFE5C2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.background,
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _t('Current account', 'الحساب الحالي'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$activeFamily ($activeUser)',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(activeMail, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                if (_savedProfiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_t('No saved accounts yet', 'لا توجد حسابات محفوظة بعد')),
                  ),
                if (_savedProfiles.isNotEmpty)
                  ..._savedProfiles.map((profile) {
                    final key = profile['profileKey']?.toString() ?? '';
                    final familyTitle = profile['familyTitle']?.toString() ?? _t('Family', 'العائلة');
                    final username = profile['username']?.toString() ?? _t('Member', 'عضو');
                    final mail = profile['mail']?.toString() ?? '';
                    final isActive = key == _activeProfileKey;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.background,
                        child: Text(
                          (username.isNotEmpty ? username[0] : 'A').toUpperCase(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text('$familyTitle ($username)'),
                      subtitle: Text(mail),
                      trailing: isActive
                          ? Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () async {
                        Navigator.of(sheetContext).pop();
                        if (!isActive) {
                          await _switchProfileFromHome(key);
                        }
                      },
                    );
                  }),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginPage()),
                          );
                        },
                        icon: Icon(Icons.add),
                        label: Text(_t('Add New Account', 'إضافة حساب جديد')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => const ManageAccountsPage()),
                          );
                          if (changed == true) {
                            await _loadUserData();
                            await _loadSavedProfiles();
                            await _fetchFamilyMembers();
                            await _loadWalletSummary();
                          }
                        },
                        icon: Icon(Icons.manage_accounts),
                        label: Text(_t('Manage Accounts', 'إدارة الحسابات')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String en, String ar) {
    return Text(
      _t(en, ar),
      style: GoogleFonts.poppins(
        fontSize: _sp(10),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.secondary,
      ),
    );
  }

  Future<void> _fetchFamilyMembers() async {
    try {
      final members = await _apiService.getAllMembers();
      setState(() {
        _familyMembers = members.map((m) => Member.fromJson(m)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('Error loading members', 'خطأ في تحميل الأعضاء')}: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await _apiService.logout();

    if (widget.onLogout != null) {
      widget.onLogout!();
    } else if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _handleLogoutAll() async {
    await _apiService.logoutAllProfiles();

    if (widget.onLogout != null) {
      widget.onLogout!();
    } else if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final usernameController = TextEditingController();
    final birthdateController = TextEditingController();
    final newMemberTypeController = TextEditingController();
    String? selectedMemberType;
    List<Map<String, dynamic>> memberTypes = [];
    bool isLoadingTypes = true;
    bool showNewTypeField = false;
    String? loadError;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch member types from database when dialog opens
            if (isLoadingTypes && memberTypes.isEmpty && loadError == null) {
              _apiService.getAllMemberTypes().then((types) {
                print('✅ Loaded ${types.length} member types: $types');
                setDialogState(() {
                  memberTypes = List<Map<String, dynamic>>.from(types);
                  isLoadingTypes = false;
                });
              }).catchError((e) {
                print('❌ Error loading member types: $e');
                setDialogState(() {
                  loadError = e.toString();
                  isLoadingTypes = false;
                });
              });
            }
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add New Member',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Mail field
                    const Text('Mail', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'Enter email address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Username field
                    const Text('Username', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        hintText: 'Enter username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Birth Date field
                    const Text('Birth Date', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: birthdateController,
                      readOnly: true,
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          birthdateController.text =
                              "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'mm/dd/yyyy',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Member Type dropdown
                    const Text('Member Type', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    isLoadingTypes
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Loading member types...'),
                              ],
                            ),
                          )
                        : loadError != null
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.red, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Error: ${loadError!.replaceAll('Exception: ', '')}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: selectedMemberType,
                                    decoration: InputDecoration(
                                      hintText: 'Select Type',
                                      hintStyle: TextStyle(color: AppColors.primary),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    items: [
                                      ...memberTypes.map((typeObj) => DropdownMenuItem(
                                            value: typeObj['type'].toString(),
                                            child: Text(typeObj['type'].toString()),
                                          )),
                                      DropdownMenuItem(
                                        value: '__CREATE_NEW__',
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Create new member type +',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == '__CREATE_NEW__') {
                                          selectedMemberType = null;
                                          showNewTypeField = true;
                                        } else {
                                          selectedMemberType = value;
                                          showNewTypeField = false;
                                          newMemberTypeController.clear();
                                        }
                                      });
                                    },
                                  ),
                                  if (showNewTypeField) ...[
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: newMemberTypeController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter new member type name',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        prefixIcon: Icon(Icons.person_add, color: AppColors.primary),
                                      ),
                                      onChanged: (value) {
                                        setDialogState(() {});
                                      },
                                    ),
                                  ],
                                ],
                              ),
                    const SizedBox(height: 24),
                    // Add Member button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: GuardedElevatedButton(
                        onPressed: () async {
                                // Validation
                                if (emailController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please enter email address')),
                                  );
                                  return;
                                }
                                if (usernameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please enter username')),
                                  );
                                  return;
                                }
                                if (birthdateController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please select birth date')),
                                  );
                                  return;
                                }

                                // Get the member type (either selected or newly created)
                                String? finalMemberType = selectedMemberType;

                                if (showNewTypeField) {
                                  if (newMemberTypeController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Please enter new member type name')),
                                    );
                                    return;
                                  }
                                  finalMemberType = newMemberTypeController.text.trim();
                                } else if (selectedMemberType == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please select member type')),
                                  );
                                  return;
                                }

                                try {
                                  final memberData = {
                                    'mail': emailController.text.trim(),
                                    'username': usernameController.text.trim(),
                                    'birth_date': birthdateController.text,
                                    'member_type': finalMemberType,
                                  };

                                  print('📝 Creating member with data: $memberData');
                                  final result = await _apiService.createMember(memberData);
                                  print('✅ Member created successfully: $result');

                                  if (mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Member added successfully!'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                    // Refresh family members
                                    _fetchFamilyMembers();
                                  }
                                } catch (e) {
                                  print('❌ Error creating member: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to add member: ${e.toString().replaceAll('Exception: ', '')}'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA8D5BA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                                'Add Member',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>(); // rebuild on palette change
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        if (_familyMembers.isNotEmpty) ...[
                          _buildFamilyMembers(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _showAddMemberDialog,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(Icons.person_add_alt_1, size: _sp(14), color: AppColors.primary),
                              label: Text(
                                _t('Add Member', 'إضافة عضو'),
                                style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ] else ...[
                          _buildAddMemberCard(),
                        ],
                        const SizedBox(height: 8),
                        _buildStatCards(),
                        const SizedBox(height: 12),
                        _buildTasksTeaser(),
                        const SizedBox(height: 10),
                        _buildAICard(),
                        const SizedBox(height: 12),
                        _buildEventsCard(),
                        const SizedBox(height: 12),
                        _buildBirthdaysCard(),
                        const SizedBox(height: 12),
                        _buildLeaderboardCard(),
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

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onLongPress: _showAccountSwitcherSheet,
          onTap: _showAccountSwitcherSheet,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.light],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _familyTitle.isNotEmpty ? _familyTitle : _t('Family Hub', 'فاميلي هب'),
                style: GoogleFonts.poppins(
                  fontSize: _sp(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                _t('Welcome back, $_userName', 'مرحباً $_userName'),
                style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.secondary),
              ),
              if (_hasActiveProfile) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.textHint),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '● ${_t("Active profile", "الحساب النشط")}',
                    style: GoogleFonts.poppins(
                      fontSize: _sp(9),
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            onPressed: () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: Text(_t('Logout options', 'خيارات تسجيل الخروج')),
                    content: Text(_t('Choose logout scope for this device.', 'اختر نطاق تسجيل الخروج لهذا الجهاز.')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                        child: Text(_t('Cancel', 'إلغاء')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop('current'),
                        child: Text(_t('Logout current', 'تسجيل خروج الحساب الحالي')),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop('all'),
                        child: Text(
                          _t('Logout all', 'تسجيل خروج جميع الحسابات'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
              if (selected == 'current') {
                await _handleLogout();
              } else if (selected == 'all') {
                await _handleLogoutAll();
              }
            },
            icon: Icon(Icons.logout_outlined, size: 22, color: AppColors.primary),
            tooltip: _t('Logout', 'خروج'),
          ),
        ),
      ],
    );
  }

  // ── ADD MEMBER CARD (shown when no members yet) ────────────────────────────

  Widget _buildAddMemberCard() {
    return GestureDetector(
      onTap: _showAddMemberDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.person_add_alt_1, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('Add your first member', 'أضف أول عضو في العائلة'),
                      style: GoogleFonts.poppins(fontSize: _sp(13), fontWeight: FontWeight.w600, color: AppColors.textDark)),
                  Text(_t('Tap to add a family member', 'اضغط لإضافة عضو'),
                      style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.secondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.border),
          ],
        ),
      ),
    );
  }

  // ── STAT CARDS ─────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final moneyBalance = ((_walletSummary['money_balance'] ?? 0) as num).toDouble();
    final pointsBalance = ((_walletSummary['points_balance'] ?? 0) as num).toDouble();

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: '💰',
            iconBg: AppColors.cardBg,
            value: '${moneyBalance.toStringAsFixed(0)} EGP',
            label: _t('Money Balance', 'رصيد المال'),
            subLabel: _t('Wallet balance', 'رصيد المحفظة'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: '⭐',
            iconBg: const Color(0xFFFFF8E1),
            value: '${pointsBalance.toStringAsFixed(0)} pts',
            label: _t('Your Points', 'نقاطك'),
            subLabel: _t('Earned points', 'نقاط مكتسبة'),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String icon,
    required Color iconBg,
    required String value,
    required String label,
    required String subLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppDecorations.card,
      child: _walletLoading
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(height: 8),
                Text(value,
                    style: GoogleFonts.poppins(fontSize: _sp(15), fontWeight: FontWeight.w700, color: AppColors.textDark)),
                Text(label, style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text(subLabel,
                    style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
    );
  }

  // ── TASKS TEASER ──────────────────────────────────────────────────────────

  Color _taskDotColor(String status) {
    switch (status) {
      case 'approved':    return AppColors.primary;
      case 'completed':   return AppColors.light;
      case 'in_progress': return const Color(0xFF1565C0);
      case 'late':        return const Color(0xFFFF5252);
      case 'rejected':    return const Color(0xFF9E9E9E);
      default:            return const Color(0xFFFB8C00); // assigned
    }
  }

  Map<String, dynamic> _taskBadge(String status) {
    switch (status) {
      case 'approved':
        return {'label': _t('Approved', 'تمت الموافقة'), 'bg': AppColors.cardBg, 'fg': AppColors.dark};
      case 'completed':
        return {'label': _t('Done ✓', 'تم ✓'), 'bg': AppColors.cardBg, 'fg': AppColors.primary};
      case 'in_progress':
        return {'label': _t('Active', 'جارٍ'), 'bg': const Color(0xFFE3F2FD), 'fg': const Color(0xFF1565C0)};
      case 'late':
        return {'label': _t('Late', 'متأخر'), 'bg': const Color(0xFFFFEBEE), 'fg': const Color(0xFFC62828)};
      case 'rejected':
        return {'label': _t('Rejected', 'مرفوض'), 'bg': const Color(0xFFF5F5F5), 'fg': const Color(0xFF9E9E9E)};
      default:
        return {'label': _t('Pending', 'قيد الانتظار'), 'bg': const Color(0xFFFFF3E0), 'fg': const Color(0xFFE65100)};
    }
  }

  Widget _buildTasksTeaser() {
    final displayTasks = _recentTasks.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader("TODAY'S TASKS", 'مهام اليوم')),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/task-management'),
              child: Text(
                _t('See all', 'عرض الكل'),
                style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppDecorations.card,
          child: _tasksLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  ),
                )
              : displayTasks.isEmpty
                  ? GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/task-management'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.assignment_outlined, color: AppColors.secondary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t('No tasks assigned yet — tap to manage', 'لا توجد مهام بعد — اضغط للإدارة'),
                                style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.secondary),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.border, size: 16),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: displayTasks.asMap().entries.map((entry) {
                        final task = entry.value as Map<String, dynamic>;
                        final isLast = entry.key == displayTasks.length - 1;
                        final title = (task['task_id'] is Map)
                            ? (task['task_id']['title'] ?? _t('Task', 'مهمة'))
                            : _t('Task', 'مهمة');
                        final mail  = task['member_mail']?.toString() ?? '';
                        final status = task['status']?.toString() ?? 'assigned';
                        final badge  = _taskBadge(status);
                        return _taskRow(
                          dot: _taskDotColor(status),
                          title: title.toString(),
                          assignee: _getMemberName(mail),
                          badge: badge['label'] as String,
                          badgeBg: badge['bg'] as Color,
                          badgeColor: badge['fg'] as Color,
                          isLast: isLast,
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _taskRow({
    required Color dot,
    required String title,
    required String assignee,
    required String badge,
    required Color badgeBg,
    required Color badgeColor,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: AppColors.primarySurface)),
      ),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.textDark),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(assignee, style: GoogleFonts.poppins(fontSize: _sp(10), color: AppColors.secondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
            child: Text(badge,
                style: GoogleFonts.poppins(fontSize: _sp(10), fontWeight: FontWeight.w600, color: badgeColor)),
          ),
        ],
      ),
    );
  }

  // ── AI CARD ───────────────────────────────────────────────────────────────

  Widget _buildAICard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/planning-chat'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text('🤖', style: TextStyle(fontSize: 15))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('Ask Family AI', 'اسأل المساعد الذكي'),
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontSize: _sp(13), fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _t('Budget, meals, tasks — ask anything', 'الميزانية، الطعام، المهام — اسأل أي شيء'),
                    style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.7), fontSize: _sp(10)),
                  ),
                ],
              ),
            ),
            Text('›',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 22, fontWeight: FontWeight.w300)),
          ],
        ),
      ),
    );
  }

  // ── EVENTS CARD ───────────────────────────────────────────────────────────

  Widget _buildEventsCard() {
    final eventIcons = ['✈️', '🎁', '🎉', '🛍️', '🏖️', '🎂'];
    final eventColors = [AppColors.light, Color(0xFFFB8C00), AppColors.primary,
                         Color(0xFFAD1457), Color(0xFF6A1B9A), AppColors.dark];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader('UPCOMING EVENTS', 'الأحداث القادمة')),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/event-funding'),
              child: Text(
                _t('See all', 'عرض الكل'),
                style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppDecorations.card,
          child: _eventsLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
                  ),
                )
              : _futureEvents.isEmpty
                  ? GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/event-funding'),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.event_outlined, color: AppColors.secondary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _t('No upcoming events — tap to create one', 'لا توجد أحداث — اضغط لإنشاء واحد'),
                                style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.secondary),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: AppColors.border, size: 16),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: _futureEvents.take(3).toList().asMap().entries.map((entry) {
                        final e   = entry.value as Map<String, dynamic>;
                        final idx = entry.key;
                        final isLast = idx == (_futureEvents.length < 3 ? _futureEvents.length - 1 : 2);
                        final color  = eventColors[idx % eventColors.length];
                        final icon   = eventIcons[idx % eventIcons.length];

                        final title     = (e['title'] ?? e['name'] ?? _t('Event', 'حدث')).toString();
                        final cost      = (e['estimated_cost'] ?? 0 as num).toDouble();
                        final saved     = ((e['total_contributed_money'] ?? e['saved_amount'] ?? 0) as num).toDouble();
                        final progress  = cost > 0 ? (saved / cost).clamp(0.0, 1.0) : 0.0;
                        final pct       = '${(progress * 100).toStringAsFixed(0)}%';
                        final amountStr = '${saved.toStringAsFixed(0)}/${cost.toStringAsFixed(0)} EGP';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: isLast ? null : Border(bottom: BorderSide(color: AppColors.primarySurface)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(9)),
                                child: Center(child: Text(icon, style: const TextStyle(fontSize: 13))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: GoogleFonts.poppins(fontSize: _sp(12), fontWeight: FontWeight.w600, color: AppColors.textDark),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(amountStr, style: GoogleFonts.poppins(fontSize: _sp(10), color: AppColors.secondary)),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: AppColors.cardBg,
                                        valueColor: AlwaysStoppedAnimation<Color>(color),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(pct,
                                  style: GoogleFonts.poppins(fontSize: _sp(12), fontWeight: FontWeight.w700, color: color)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  // ── BIRTHDAYS CARD ────────────────────────────────────────────────────────

  // Friendly "in N days" / "Today!" / "Tomorrow" label.
  String _birthdayWhen(int days) {
    if (days <= 0) return _t('Today 🎉', 'اليوم 🎉');
    if (days == 1) return _t('Tomorrow', 'غدًا');
    return _t('in $days days', 'خلال $days يوم');
  }

  Widget _buildBirthdaysCard() {
    // While loading, show nothing to avoid a flash; once loaded, hide if no
    // birthdays in the next 30 days so the home page stays clean.
    if (_birthdaysLoading || _upcomingBirthdays.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('UPCOMING BIRTHDAYS', 'أعياد الميلاد القادمة'),
        const SizedBox(height: 8),
        Container(
          decoration: AppDecorations.card,
          child: Column(
            children: _upcomingBirthdays.take(4).toList().asMap().entries.map((entry) {
              final b   = entry.value as Map<String, dynamic>;
              final idx = entry.key;
              final count = _upcomingBirthdays.length < 4 ? _upcomingBirthdays.length : 4;
              final isLast = idx == count - 1;

              final name    = (b['username'] ?? '').toString();
              final days    = (b['days_until'] ?? 0) as int;
              final age     = (b['turning_age'] ?? 0) as int;
              final isToday = b['is_today'] == true;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(bottom: BorderSide(color: AppColors.primarySurface)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(9)),
                      child: const Center(child: Text('🎂', style: TextStyle(fontSize: 13))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: GoogleFonts.poppins(fontSize: _sp(12), fontWeight: FontWeight.w600, color: AppColors.textDark),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(_t('Turning $age', 'يبلغ $age'),
                              style: GoogleFonts.poppins(fontSize: _sp(10), color: AppColors.secondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(_birthdayWhen(days),
                        style: GoogleFonts.poppins(
                          fontSize: _sp(11),
                          fontWeight: FontWeight.w700,
                          color: isToday ? AppColors.primary : AppColors.secondary,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── LEADERBOARD CARD ──────────────────────────────────────────────────────

  Widget _buildLeaderboardCard() {
    const medals = ['🥇', '🥈', '🥉'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeader('POINTS LEADERBOARD', 'لوحة المتصدرين')),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/family-points'),
              child: Text(
                _t('Full ranking', 'الترتيب الكامل'),
                style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppDecorations.card,
          child: _rankingLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : _pointsRanking.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: Center(
                        child: Text(
                          _t('No points data yet', 'لا توجد بيانات نقاط بعد'),
                          style: GoogleFonts.poppins(color: AppColors.secondary, fontSize: _sp(12)),
                        ),
                      ),
                    )
                  : Column(
                      children: _pointsRanking.take(3).toList().asMap().entries.map((entry) {
                        final idx    = entry.key;
                        final member = entry.value as Map<String, dynamic>;
                        final isLast = idx == (_pointsRanking.length < 3 ? _pointsRanking.length - 1 : 2);
                        final medal  = idx < medals.length ? medals[idx] : '${idx + 1}.';
                        final name   = (member['username'] ?? member['mail'] ?? '?').toString();
                        final pts    = (member['total_points'] ?? 0 as num).toInt();

                        // Find matching Member for avatar emoji
                        String emoji = '👤';
                        final mail = (member['mail'] ?? '').toString();
                        for (final m in _familyMembers) {
                          if (m.mail == mail) { emoji = m.getAvatarEmoji(); break; }
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            border: isLast ? null : Border(bottom: BorderSide(color: AppColors.primarySurface)),
                          ),
                          child: Row(
                            children: [
                              Text(medal, style: const TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(emoji, style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(name,
                                    style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.textDark),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              Text(
                                '$pts pts',
                                style: GoogleFonts.poppins(
                                    fontSize: _sp(12), fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ),
      ],
    );
  }

  // ── FAMILY MEMBERS (KEEP EXACTLY) ─────────────────────────────────────────

  Widget _buildFamilyMembers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('FAMILY MEMBERS', 'أفراد العائلة'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppDecorations.cardWithShadow,
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: _familyMembers.asMap().entries
                      .map((e) => _buildMemberCard(e.value, e.key))
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Member member, int index) {
    final avatarColor = _avatarColors[index % _avatarColors.length];
    final avatarBg = _avatarBgs[index % _avatarBgs.length];
    return GestureDetector(
      onTap: () => _showMemberOptionsDialog(member, index),
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      member.getAvatarEmoji(),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              member.username,
              style: GoogleFonts.poppins(fontSize: _sp(11), color: const Color(0xFF333333), fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              member.memberType?.type ?? _t('Member', 'عضو'),
              style: TextStyle(
                fontSize: _sp(10),
                color: avatarColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberOptionsDialog(Member member, int index) {
    final avatarColor = _avatarColors[index % _avatarColors.length];
    final avatarBg = _avatarBgs[index % _avatarBgs.length];
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Member Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarColor.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      member.getAvatarEmoji(),
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Member Name
                Text(
                  member.username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Member Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    member.memberType?.type ?? _t('Member', 'عضو'),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Member Email
                Text(
                  member.mail,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Close Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Remove Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _showDeleteMemberConfirmation(member);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_remove, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Remove',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteMemberConfirmation(Member member) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool isDeleting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Remove Member'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to remove "${member.username}" from your family?',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action cannot be undone. All member data including points and wishlist will be deleted.',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(dialogContext),
                  child: Text(_t('Cancel', 'إلغاء')),
                ),
                GuardedElevatedButton(
                  onPressed: () async {
                          try {
                            await _apiService.deleteMember(member.id);

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${member.username} has been removed from your family'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Refresh family members list
                              _fetchFamilyMembers();
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to remove member: ${e.toString().replaceAll('Exception: ', '')}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.white),
                    ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── BOTTOM NAV ────────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, '🏠', _t('Home', 'الرئيسية')),
              _buildNavItem(1, '⊞', _t('Dashboard', 'لوحة التحكم')),
              _buildNavItem(2, '🤖', _t('AI Chat', 'المساعد')),
              _buildNavItem(3, '📍', _t('Location', 'الموقع')),
              _buildNavItem(4, '⚙️', _t('Settings', 'الإعدادات')),
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
            setState(() => _activeTab = 0);
            break;
          case 1:
            Navigator.pushNamed(context, '/dashboard');
            break;
          case 2:
            Navigator.pushNamed(context, '/planning-chat');
            break;
          case 3:
            Navigator.pushNamed(context, '/family-map');
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingPage(onLogout: widget.onLogout),
              ),
            );
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 28,
            decoration: BoxDecoration(
              color: isActive ? AppColors.cardBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: _sp(10),
              color: isActive ? AppColors.primary : Color(0xFF9E9E9E),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
