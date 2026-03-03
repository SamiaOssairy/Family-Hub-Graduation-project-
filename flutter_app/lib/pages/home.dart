import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/models/member_model.dart';
import 'setting.dart';

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
  
  int _activeTab = 0;
  bool _locationSharing = true;
  bool _protectionSetting = false;
  List<Member> _familyMembers = [];
  String _familyTitle = '';
  String _userName = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchFamilyMembers();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('username') ?? widget.userName ?? '';
    final familyTitle = prefs.getString('familyTitle') ?? widget.familyTitle ?? '';
    
    setState(() {
      _userName = userName;
      _familyTitle = familyTitle;
    });
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
          SnackBar(content: Text('Error loading members: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await _apiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
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
    bool isLoading = false;
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
                          icon: const Icon(Icons.close),
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
                        suffixIcon: const Icon(Icons.calendar_today),
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
                              border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF4CAF50),
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
                                      hintStyle: const TextStyle(color: Color(0xFF4CAF50)),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    items: [
                                      ...memberTypes.map((typeObj) => DropdownMenuItem(
                                            value: typeObj['type'].toString(),
                                            child: Text(typeObj['type'].toString()),
                                          )),
                                      const DropdownMenuItem(
                                        value: '__CREATE_NEW__',
                                        child: Row(
                                          children: [
                                            Icon(Icons.add_circle_outline, color: Color(0xFF4CAF50), size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Create new member type +',
                                              style: TextStyle(
                                                color: Color(0xFF4CAF50),
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
                                        prefixIcon: const Icon(Icons.person_add, color: Color(0xFF4CAF50)),
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
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                // Validation
                                if (emailController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter email address')),
                                  );
                                  return;
                                }
                                if (usernameController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter username')),
                                  );
                                  return;
                                }
                                if (birthdateController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select birth date')),
                                  );
                                  return;
                                }
                                
                                // Get the member type (either selected or newly created)
                                String? finalMemberType = selectedMemberType;
                                
                                if (showNewTypeField) {
                                  if (newMemberTypeController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter new member type name')),
                                    );
                                    return;
                                  }
                                  finalMemberType = newMemberTypeController.text.trim();
                                } else if (selectedMemberType == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please select member type')),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = true;
                                });

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
                                      const SnackBar(
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
                                } finally {
                                  if (mounted) {
                                    setDialogState(() {
                                      isLoading = false;
                                    });
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA8D5BA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFF3F4F6),
              Color(0xFFE8F5E9),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      if (_familyMembers.isNotEmpty) _buildFamilyMembers(),
                      const SizedBox(height: 30),
                      _buildQuickActions(),
                      const SizedBox(height: 30),
                      _buildUpcomingActivities(),
                      const SizedBox(height: 30),
                      _buildSafetySettings(),
                      const SizedBox(height: 100), // Space for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF4CAF50), width: 3),
                  color: Colors.white,
                ),
                child: const Icon(Icons.family_restroom, color: Color(0xFF4CAF50), size: 35),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _familyTitle.isNotEmpty ? '$_familyTitle Family' : 'Family Hub',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome $_userName',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
            side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMembers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Family Members',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: _familyMembers.map((member) => _buildMemberCard(member)).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(Member member) {
    return GestureDetector(
      onTap: () => _showMemberOptionsDialog(member),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4E7D7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      member.getAvatarEmoji(),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              member.username,
              style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              member.memberType?.type ?? 'Member',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberOptionsDialog(Member member) {
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFD4E7D7),
                    shape: BoxShape.circle,
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
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    member.memberType?.type ?? 'Member',
                    style: const TextStyle(
                      color: Color(0xFF4CAF50),
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
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Color(0xFF4CAF50)),
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
                      color: Colors.red.withOpacity(0.1),
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
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() {
                            isDeleting = true;
                          });
                          
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
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
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

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _showAddMemberDialog(),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Add New Member',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
           
                        color: const Color(0xFFF5F9F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.home, color: Color(0xFF4CAF50), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Weekly Chores Complete: 70%',
                              style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: Stack(
                            children: [
                              CircularProgressIndicator(
                                value: 0.7,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                                strokeWidth: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Invites (1)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              'Awaiting acceptance',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF4CAF50)),
                        foregroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Set Family Title'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('View Family Hub'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // Task Management Button
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/task-management'),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Task Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingActivities() {
    final activities = [
      {'title': 'Requirements Gathering', 'date': 'Mon, 8pm', 'icon': '📄'},
      {'title': 'Family Movie Night', 'date': 'Fri, 8pm', 'icon': '🎬'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Activities',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Mini Calendar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCalendarColumn('Sat', [1, 2, 3, 4]),
                  _buildCalendarColumn('Mon', [5, 6, 7, 8]),
                  _buildCalendarColumn('Tue', [9, 10, 11, 12]),
                  _buildCalendarColumn('Wed', [13, 14, 15, 16]),
                  _buildCalendarColumn('Thu', [17, 18, 19, 20], selectedDay: 20),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 15),
              // Activities List
              ...activities.map((activity) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F9F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              activity['icon']!,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity['title']!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              Text(
                                activity['date']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: false,
                          onChanged: (value) {},
                          activeColor: const Color(0xFF4CAF50),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarColumn(String day, List<int> dates, {int? selectedDay}) {
    return Column(
      children: [
        Text(
          day,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        ...dates.map((date) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: date == selectedDay ? const Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    date.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: date == selectedDay ? Colors.white : const Color(0xFF666666),
                      fontWeight: date == selectedDay ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildSafetySettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Safety & Connection',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.location_on,
                title: 'Location Sharing On',
                subtitle: 'App Access Control',
                value: _locationSharing,
                onChanged: (value) {
                  setState(() {
                    _locationSharing = value;
                  });
                },
              ),
              const SizedBox(height: 15),
              _buildSettingItem(
                icon: Icons.shield,
                title: 'View Protection Setting',
                subtitle: null,
                value: _protectionSetting,
                onChanged: (value) {
                  setState(() {
                    _protectionSetting = value;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.dashboard, 'Dashboard', 1),
              _buildNavItem(Icons.checklist, 'Tasks', 2),
              _buildNavItem(Icons.stars, 'Points', 3),
              _buildNavItem(Icons.settings, 'Settings', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        switch (index) {
          case 0:
            setState(() => _activeTab = index);
            break;
          case 1:
            Navigator.pushNamed(context, '/dashboard');
            break;
          case 2:
            Navigator.pushNamed(context, '/tasks');
            break;
          case 3:
            Navigator.pushNamed(context, '/family-points');
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF999999),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF999999),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}