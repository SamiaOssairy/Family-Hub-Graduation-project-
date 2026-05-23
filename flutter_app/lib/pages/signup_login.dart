import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/styling/responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/localization/app_i18n.dart';
import '../core/widgets/language_switch_chip.dart';
import 'home.dart';
import 'manage_accounts_page.dart';

// ─── Shared input decoration ────────────────────────────────────────────────
InputDecoration _fieldDeco(String hint, IconData icon, {Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
    prefixIcon: Icon(icon, color: const Color(0xFF00897B), size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF0FAFA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

// ─── Shared primary button style ────────────────────────────────────────────
ButtonStyle _primaryBtn() => ElevatedButton.styleFrom(
  backgroundColor: const Color(0xFF00897B),
  foregroundColor: Colors.white,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 3,
  shadowColor: const Color(0xFF00897B).withOpacity(0.35),
);

// ================= LOGIN PAGE =================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService _apiService = ApiService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  List<Map<String, dynamic>> _savedProfiles = [];
  String _activeProfileKey = '';

  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfiles() async {
    final profiles = await _apiService.getSavedProfiles();
    final activeKey = await _apiService.getActiveProfileKey() ?? '';
    if (!mounted) return;
    setState(() {
      _savedProfiles = profiles;
      _activeProfileKey = activeKey;
    });
  }

  Future<void> _quickSwitchProfile(String profileKey) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.switchProfile(profileKey);
      if (!mounted) return;
      _navigateToHomeAfterQuickSwitch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Failed to switch profile', 'فشل تبديل الحساب')}: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHomeAfterQuickSwitch() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const HomePage(),
      ),
      (route) => false,
    );
  }

  Future<void> _removeSavedProfile(String profileKey) async {
    try {
      await _apiService.removeSavedProfile(profileKey);
      await _loadSavedProfiles();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Saved profile removed', 'تم حذف الحساب المحفوظ'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Failed to remove profile', 'فشل حذف الحساب')}: ${e.toString().replaceAll('Exception: ', '')}'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                  _t('Switch Account', 'تبديل الحساب'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFB2DFDB)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFE0F2F1),
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Color(0xFF00897B),
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
                                    color: Color(0xFF00897B),
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
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(_t('No saved accounts yet', 'لا توجد حسابات محفوظة بعد')),
                  ),
                if (_savedProfiles.isNotEmpty)
                  ..._savedProfiles.map((profile) {
                    final profileKey = profile['profileKey']?.toString() ?? '';
                    final familyTitle = profile['familyTitle']?.toString() ?? _t('Family', 'العائلة');
                    final username = profile['username']?.toString() ?? _t('Member', 'عضو');
                    final mail = profile['mail']?.toString() ?? '';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFE0F2F1),
                        child: Text(
                          (username.isNotEmpty ? username[0] : 'A').toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text('$familyTitle ($username)'),
                      subtitle: Text(mail),
                      onTap: _isLoading
                          ? null
                          : () async {
                              Navigator.of(sheetContext).pop();
                              await _quickSwitchProfile(profileKey);
                            },
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          setState(() {
                            _emailController.clear();
                          });
                        },
                        icon: Icon(Icons.add),
                        label: Text(_t('Add New Account', 'إضافة حساب جديد')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B),
                          side: const BorderSide(color: Color(0xFF00897B)),
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
                            await _loadSavedProfiles();
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

  Future<void> _handleEmailSubmit() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter your email', 'يرجى إدخال البريد الإلكتروني'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final mail = _emailController.text.trim();

      final families = await _apiService.getFamiliesByEmail(mail);
      if (!mounted) return;

      if (families.isEmpty) {
        throw Exception(_t('No family found for this email', 'لم يتم العثور على عائلة لهذا البريد'));
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FamilyPasswordLoginPage(
            email: mail,
            families: families,
          ),
        ),
      );
    } catch (e) {
      print('❌ Email step error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('Could not continue', 'تعذر المتابعة')}: ${e.toString().replaceAll('Exception: ', '')}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F5),
      body: Center(
        child: SingleChildScrollView(
          child: ContentContainer(
            maxWidth: 420,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: LanguageSwitchChip(),
                ),
                const SizedBox(height: 8),
                // Security Icon
                GestureDetector(
                  onLongPress: _showAccountSwitcherSheet,
                  onTap: _showAccountSwitcherSheet,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2F1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFB2DFDB), width: 1.4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Image.asset(
                        'assets/security_icon.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _t('Long press icon to switch accounts', 'اضغط مطولاً على الأيقونة لتبديل الحسابات'),
                  style: TextStyle(fontSize: 11, color: Color(0xFF4DB6AC)),
                ),
                const SizedBox(height: 32),
                
                // Welcome Back Text
                Text(
                  _t('Welcome Back!', 'مرحباً بعودتك!'),
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                if (_savedProfiles.isNotEmpty) const SizedBox(height: 16),
                if (_savedProfiles.isNotEmpty)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _savedProfiles.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final profile = _savedProfiles[index];
                        final profileKey = profile['profileKey']?.toString() ?? '';
                        final familyTitle = profile['familyTitle']?.toString() ?? _t('Family', 'العائلة');
                        final username = profile['username']?.toString() ?? _t('Member', 'عضو');

                        return InputChip(
                          label: Text(
                            '$familyTitle ($username)',
                            style: const TextStyle(
                              color: Color(0xFF00897B),
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF00897B)),
                          onPressed: _isLoading
                              ? null
                              : () => _quickSwitchProfile(profileKey),
                          onDeleted: _isLoading
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) {
                                      return AlertDialog(
                                        title: Text(_t('Remove saved profile?', 'حذف الحساب المحفوظ؟')),
                                        content: Text(_t('Remove $familyTitle ($username) from this device?', 'حذف $familyTitle ($username) من هذا الجهاز؟')),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(dialogContext).pop(false),
                                            child: Text(_t('Cancel', 'إلغاء')),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(dialogContext).pop(true),
                                            child: Text(_t('Remove', 'حذف'), style: const TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      );
                                    },
                                  );

                                  if (confirmed == true) {
                                    await _removeSavedProfile(profileKey);
                                  }
                                },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 28),

                // Email TextField
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDeco(
                    _t('Email', 'البريد الإلكتروني'),
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailSubmit,
                    style: _primaryBtn(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _t('Continue', 'متابعة'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Security note
                Text(
                  _t('Your data is securely encrypted', 'بياناتك مشفرة بالكامل'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF999999), fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _t("Don't have an account? ", 'ليس لديك حساب؟ '),
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: Text(
                        _t('Sign Up', 'إنشاء حساب'),
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class FamilyPasswordLoginPage extends StatefulWidget {
  final String email;
  final List<dynamic> families;

  const FamilyPasswordLoginPage({
    super.key,
    required this.email,
    required this.families,
  });

  @override
  State<FamilyPasswordLoginPage> createState() => _FamilyPasswordLoginPageState();
}

class _FamilyPasswordLoginPageState extends State<FamilyPasswordLoginPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _selectedFamilyId;

  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  @override
  void initState() {
    super.initState();
    if (widget.families.length == 1) {
      _selectedFamilyId = widget.families.first['family_id']?.toString();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_selectedFamilyId == null || _selectedFamilyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please choose your family', 'يرجى اختيار العائلة'))),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter your password', 'يرجى إدخال كلمة المرور'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.login({
        'mail': widget.email,
        'password': _passwordController.text,
        'family_id': _selectedFamilyId,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', response['data']['username'] ?? '');
      await prefs.setString('familyTitle', response['data']['familyTitle'] ?? '');

      final isFirstLogin = response['data']['isFirstLogin'] ?? false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Welcome ${response['data']['username']}!', 'مرحباً ${response['data']['username']}!'))),
      );

      if (isFirstLogin) {
        _showSetPasswordDialog(
          username: response['data']['username'],
          familyTitle: response['data']['familyTitle'],
        );
      } else {
        _navigateToHome(
          response['data']['username'],
          response['data']['familyTitle'],
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Login failed', 'فشل تسجيل الدخول')}: ${e.toString().replaceAll('Exception: ', '')}'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome(String? username, String? familyTitle) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => HomePage(
          userName: username,
          familyTitle: familyTitle,
          onLogout: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          },
        ),
      ),
      (route) => false,
    );
  }

  void _showSetPasswordDialog({String? username, String? familyTitle}) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Set Your Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome ${username ?? ''}! Please set your personal password to secure your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: 'Enter new password',
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setDialogState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setDialogState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          'Password must be at least 6 characters',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (newPasswordController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Please enter a password')),
                                  );
                                  return;
                                }

                                // TESTING PHASE ONLY:
                                // Minimum password length check is temporarily disabled.
                                // Re-enable before release.
                                // if (newPasswordController.text.length < 6) {
                                //   ScaffoldMessenger.of(context).showSnackBar(
                                //     SnackBar(content: Text('Password must be at least 6 characters')),
                                //   );
                                //   return;
                                // }

                                if (newPasswordController.text != confirmPasswordController.text) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Passwords do not match')),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isLoading = true;
                                });

                                try {
                                  await _apiService.setPassword(
                                    newPassword: newPasswordController.text,
                                    confirmPassword: confirmPasswordController.text,
                                  );

                                  if (mounted) {
                                    Navigator.pop(dialogContext);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Password set successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    _navigateToHome(username, familyTitle);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
                                        backgroundColor: Colors.red,
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
                          backgroundColor: const Color(0xFF00897B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Set Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
      backgroundColor: const Color(0xFFE8F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8F5F5),
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(_t('Choose Family', 'اختر العائلة')),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ContentContainer(
            maxWidth: 420,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: LanguageSwitchChip(),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                Text(
                  _t('Continue Login', 'متابعة تسجيل الدخول'),
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 14, color: Color(0xFF00897B)),
                    const SizedBox(width: 6),
                    Text(
                      widget.email,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Family picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB2DFDB)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.family_restroom, color: Color(0xFF00897B), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedFamilyId,
                            hint: Text(_t('Select family', 'اختر العائلة'),
                                style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                            items: widget.families.map((family) {
                              final familyId = family['family_id']?.toString() ?? '';
                              final title = family['familyTitle']?.toString() ?? _t('Family', 'العائلة');
                              final username = family['username']?.toString() ?? '';
                              return DropdownMenuItem<String>(
                                value: familyId,
                                child: Text('$title ($username)'),
                              );
                            }).toList(),
                            onChanged: (value) => setState(() => _selectedFamilyId = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Password field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _fieldDeco(
                    _t('Password', 'كلمة المرور'),
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF888888),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: _primaryBtn(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _t('Log In', 'تسجيل الدخول'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= SIGNUP PAGE =================
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final ApiService _apiService = ApiService();
  final _emailController = TextEditingController();
  final _birthdateController = TextEditingController();
  final _familyTitleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF00897B),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _birthdateController.text = 
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _birthdateController.dispose();
    _familyTitleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    // Validation
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter your email', 'يرجى إدخال البريد الإلكتروني'))),
      );
      return;
    }

    if (_birthdateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please select your birthdate', 'يرجى اختيار تاريخ الميلاد'))),
      );
      return;
    }

    if (_familyTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter family title', 'يرجى إدخال اسم العائلة'))),
      );
      return;
    }

    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter a username', 'يرجى إدخال اسم المستخدم'))),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter your password', 'يرجى إدخال كلمة المرور'))),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Passwords do not match', 'كلمتا المرور غير متطابقتين'))),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare data for backend API
      final signupData = {
        'mail': _emailController.text.trim(),
        'password': _passwordController.text,
        'Title': _familyTitleController.text.trim(),
        'username': _usernameController.text.trim(),
        'birth_date': _birthdateController.text,
      };

      final response = await _apiService.signup(signupData);

      // Save token and user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', response['data']['username'] ?? '');
      await prefs.setString('familyTitle', response['data']['familyTitle'] ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Account created successfully! Please login.', 'تم إنشاء الحساب بنجاح! يرجى تسجيل الدخول.'))),
        );
        
        // Navigate to login page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('Signup failed', 'فشل إنشاء الحساب')}: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5F5),
      body: Center(
        child: SingleChildScrollView(
          child: ContentContainer(
            maxWidth: 420,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: LanguageSwitchChip(),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 40),
                
                // Parent Icon
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2F1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFB2DFDB), width: 1.4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Image.asset(
                      'assets/parent_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                // Title
                Text(
                  _t('Create Your Account', 'أنشئ حسابك'),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t('Family admin — you manage the whole hub', 'مدير العائلة — أنت تدير كل شيء'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Email TextField
                _buildTextField(
                  controller: _emailController,
                  hintText: _t('Email', 'البريد الإلكتروني'),
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                // Birthdate TextField
                TextField(
                  controller: _birthdateController,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  decoration: _fieldDeco(
                    _t('Birthdate', 'تاريخ الميلاد'),
                    Icons.cake_outlined,
                    suffix: Icon(Icons.calendar_today, color: Color(0xFF00897B), size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                // Family Title TextField
                _buildTextField(
                  controller: _familyTitleController,
                  hintText: _t('Family Title', 'اسم العائلة'),
                  icon: Icons.home_outlined,
                ),
                const SizedBox(height: 14),

                // Username TextField
                _buildTextField(
                  controller: _usernameController,
                  hintText: _t('Username', 'اسم المستخدم'),
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 14),

                // Password TextField
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _fieldDeco(
                    _t('Password', 'كلمة المرور'),
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF888888),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm Password TextField
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _fieldDeco(
                    _t('Confirm Password', 'تأكيد كلمة المرور'),
                    Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF888888),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    style: _primaryBtn(),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _t('Sign Up', 'إنشاء حساب'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _t('Already have Family Account ? ', 'هل لديك حساب عائلة بالفعل؟ '),
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        _t('Login', 'تسجيل الدخول'),
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData icon = Icons.edit_outlined,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _fieldDeco(hintText, icon),
    );
  }
}