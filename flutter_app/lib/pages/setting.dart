import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization/app_i18n.dart';
import '../core/models/member_model.dart';
import '../core/services/api_service.dart';
import '../core/services/locale_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/app_bottom_nav.dart';

class SettingPage extends StatefulWidget {
  final VoidCallback? onLogout;
  const SettingPage({super.key, this.onLogout});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final ApiService _apiService = ApiService();
  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  // ── State ─────────────────────────────────────────────────────────────────
  String _familyTitle = '';
  String _currentUsername = '';
  List<Map<String, dynamic>> _savedProfiles = [];
  String _activeProfileKey = '';
  bool _locationSharing = true;
  bool _isUpdatingLocationSharing = false;
  String _languageCode = 'en';
  bool _notificationsEnabled = true;
  bool _isParent = false;
  double _moneyToPointsRate = 10.0;
  double _pointsToMoneyRate = 0.05;
  List<Member> _familyMembers = [];
  bool _membersLoading = true;

  double _sp(double size) {
    final w = MediaQuery.of(context).size.width.clamp(320.0, 480.0);
    return size * (w / 390.0);
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.border, width: 0.8),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSavedProfiles();
    _loadLocationSharing();
    _loadPreferences();
    _checkIsParent();
    _loadFamilyMembers();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _familyTitle = prefs.getString('familyTitle') ?? '';
      _activeProfileKey = prefs.getString('activeProfileKey') ?? '';
      _languageCode = prefs.getString('app_locale') ?? 'en';
      _currentUsername = prefs.getString('username') ?? '';
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true);
    try {
      final balance = await _apiService.getCombinedBalance();
      final rate = balance['conversionRate'];
      if (rate is Map && mounted) {
        setState(() {
          _moneyToPointsRate = (rate['money_to_points_rate'] as num?)?.toDouble() ?? 10.0;
          _pointsToMoneyRate = (rate['points_to_money_rate'] as num?)?.toDouble() ?? 0.05;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkIsParent() async {
    try {
      final result = await _apiService.isParent();
      if (mounted) setState(() => _isParent = result);
    } catch (_) {}
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final members = await _apiService.getAllMembers();
      if (!mounted) return;
      setState(() {
        _familyMembers = members.map((m) => Member.fromJson(m)).toList();
        _membersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _membersLoading = false);
    }
  }

  Future<void> _loadSavedProfiles() async {
    final profiles = await _apiService.getSavedProfiles();
    if (!mounted) return;
    setState(() => _savedProfiles = profiles);
  }

  Future<void> _loadLocationSharing() async {
    try {
      final response = await _apiService.getMyLocation();
      final location = response['data']?['location'];
      if (location != null && mounted) {
        setState(() => _locationSharing = location['is_sharing_enabled'] ?? true);
      }
    } catch (_) {}
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value
            ? _t('Notifications enabled', 'تم تفعيل الإشعارات')
            : _t('Notifications disabled', 'تم إيقاف الإشعارات')),
      ));
    }
  }

  Future<void> _toggleLocationSharingFromSettings(bool value) async {
    if (_isUpdatingLocationSharing) return;
    final previous = _locationSharing;
    setState(() { _locationSharing = value; _isUpdatingLocationSharing = true; });
    try {
      await _apiService.toggleLocationSharing(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value
            ? _t('Location sharing enabled', 'تم تفعيل مشاركة الموقع')
            : _t('Location sharing disabled', 'تم إيقاف مشاركة الموقع')),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationSharing = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_t('Failed', 'فشل')}: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isUpdatingLocationSharing = false);
    }
  }

  Future<void> _switchToProfile(String profileKey) async {
    try {
      await _apiService.switchProfile(profileKey);
      await _loadUserData();
      await _loadSavedProfiles();
      await _loadLocationSharing();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Profile switched successfully', 'تم تبديل الحساب بنجاح'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_t('Failed', 'فشل')}: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _removeProfile(String profileKey) async {
    try {
      final wasActive = profileKey == _activeProfileKey;
      await _apiService.removeSavedProfile(profileKey);
      await _loadSavedProfiles();
      await _loadUserData();
      if (!mounted) return;
      if (wasActive && _savedProfiles.isEmpty) {
        widget.onLogout != null
            ? widget.onLogout!()
            : Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Profile removed', 'تم حذف الحساب'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${_t('Failed', 'فشل')}: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _handleLogoutCurrent() async {
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

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showEditProfileDialog() {
    final usernameCtrl = TextEditingController(text: _currentUsername);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_t('Edit Profile', 'تعديل الملف الشخصي'),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: usernameCtrl,
          decoration: InputDecoration(
            labelText: _t('Username', 'اسم المستخدم'),
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Cancel', 'إلغاء'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final name = usernameCtrl.text.trim();
              if (name.isEmpty) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('username', name);
              if (mounted) {
                setState(() => _currentUsername = name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_t('Profile updated', 'تم تحديث الملف الشخصي')),
                  backgroundColor: AppColors.primary,
                ));
              }
            },
            child: Text(_t('Save', 'حفظ'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFamilyMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                  color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(_t('Family Members', 'أفراد العائلة'),
                      style: GoogleFonts.poppins(
                          fontSize: _sp(16), fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (_isParent)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        Navigator.pushNamed(context, '/home');
                      },
                      icon: const Icon(Icons.person_add, size: 16, color: AppColors.primary),
                      label: Text(_t('Add', 'إضافة'),
                          style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.primary)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            Expanded(
              child: _membersLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _familyMembers.isEmpty
                      ? Center(child: Text(_t('No members found', 'لا يوجد أعضاء'),
                          style: GoogleFonts.poppins(color: AppColors.textSecondary)))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _familyMembers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                          itemBuilder: (_, i) {
                            final m = _familyMembers[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primarySurface,
                                child: Text(m.getAvatarEmoji(), style: const TextStyle(fontSize: 18)),
                              ),
                              title: Text(m.username,
                                  style: GoogleFonts.poppins(
                                      fontSize: _sp(13), fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              subtitle: Text(m.memberType?.type ?? _t('Member', 'عضو'),
                                  style: GoogleFonts.poppins(
                                      fontSize: _sp(11), color: AppColors.textSecondary)),
                              trailing: Text(m.mail,
                                  style: GoogleFonts.poppins(
                                      fontSize: _sp(9), color: AppColors.textHint),
                                  overflow: TextOverflow.ellipsis),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConversionRateDialog() {
    final moneyCtrl = TextEditingController(text: _moneyToPointsRate.toStringAsFixed(0));
    final ptsCtrl = TextEditingController(
        text: (_pointsToMoneyRate * 100).toStringAsFixed(0));
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(_t('Conversion Rates', 'أسعار التحويل'),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _t('Current: 1 EGP = ${_moneyToPointsRate.toStringAsFixed(0)} pts  |  100 pts = ${(_pointsToMoneyRate * 100).toStringAsFixed(0)} EGP',
                      'حالياً: 1 جنيه = ${_moneyToPointsRate.toStringAsFixed(0)} نقطة  |  100 نقطة = ${(_pointsToMoneyRate * 100).toStringAsFixed(0)} جنيه'),
                  style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: moneyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('Points per 1 EGP', 'نقاط لكل جنيه'),
                  prefixIcon: const Icon(Icons.monetization_on_outlined, color: AppColors.primary),
                  helperText: _t('Default: 10', 'الافتراضي: 10'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ptsCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t('EGP per 100 pts', 'جنيه لكل 100 نقطة'),
                  prefixIcon: const Icon(Icons.stars_outlined, color: AppColors.primary),
                  helperText: _t('Default: 5', 'الافتراضي: 5'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Cancel', 'إلغاء'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: saving ? null : () async {
                final m2p = double.tryParse(moneyCtrl.text.trim());
                final p2m = double.tryParse(ptsCtrl.text.trim());
                if (m2p == null || p2m == null || m2p <= 0 || p2m <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(_t('Enter valid positive numbers', 'أدخل أرقاماً موجبة صحيحة'))));
                  return;
                }
                setDs(() => saving = true);
                try {
                  await _apiService.setConversionRate(
                    moneyToPointsRate: m2p,
                    pointsToMoneyRate: p2m / 100,
                  );
                  if (mounted) {
                    setState(() { _moneyToPointsRate = m2p; _pointsToMoneyRate = p2m / 100; });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(_t('Rates updated', 'تم تحديث الأسعار')),
                      backgroundColor: AppColors.primary,
                    ));
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ));
                } finally {
                  setDs(() => saving = false);
                }
              },
              child: saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_t('Save', 'حفظ'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Select Language', 'اختر اللغة')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(_t('English', 'الإنجليزية')),
              value: 'en', groupValue: _languageCode,
              activeColor: AppColors.primary,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: Text(_t('Arabic', 'العربية')),
              value: 'ar', groupValue: _languageCode,
              activeColor: AppColors.primary,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Cancel', 'إلغاء')))],
      ),
    );
    if (selected == null || selected == _languageCode) return;
    await LocaleService.setLocale(Locale(selected));
    if (!mounted) return;
    setState(() => _languageCode = selected);
  }

  void _showSwitchProfileDialog() {
    if (_savedProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t('No saved profiles.', 'لا توجد حسابات محفوظة.')),
      ));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('Switch Profile', 'تبديل الحساب')),
        content: SizedBox(
          width: 420,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _savedProfiles.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = _savedProfiles[i];
              final key = p['profileKey']?.toString() ?? '';
              final isActive = key == _activeProfileKey;
              final title = p['familyTitle']?.toString() ?? '';
              final username = p['username']?.toString() ?? '';
              final mail = p['mail']?.toString() ?? '';
              return ListTile(
                title: Text('$title ($username)'),
                subtitle: Text(mail),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive) const Icon(Icons.check_circle, color: AppColors.primary),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            content: Text('${_t('Remove', 'حذف')} $title ($username)?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(_t('Cancel', 'إلغاء'))),
                              TextButton(onPressed: () => Navigator.pop(c, true),
                                  child: Text(_t('Remove', 'حذف'), style: const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (ok == true) await _removeProfile(key);
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!isActive) await _switchToProfile(key);
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Close', 'إغلاق')))],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false, obsC = true, obsN = true, obsConf = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('Change Password', 'تغيير كلمة المرور'),
                          style: GoogleFonts.poppins(fontSize: _sp(18), fontWeight: FontWeight.w700)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _pwField(currentCtrl, _t('Current Password', 'كلمة المرور الحالية'), obsC, Icons.lock_outline,
                      () => setDs(() => obsC = !obsC)),
                  const SizedBox(height: 10),
                  _pwField(newCtrl, _t('New Password', 'كلمة المرور الجديدة'), obsN, Icons.lock,
                      () => setDs(() => obsN = !obsN)),
                  const SizedBox(height: 10),
                  _pwField(confirmCtrl, _t('Confirm Password', 'تأكيد كلمة المرور'), obsConf, Icons.lock,
                      () => setDs(() => obsConf = !obsConf)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: loading ? null : () async {
                        if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(_t('Fill all fields', 'يرجى ملء جميع الحقول'))));
                          return;
                        }
                        if (newCtrl.text != confirmCtrl.text) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(_t('Passwords do not match', 'كلمتا المرور غير متطابقتين'))));
                          return;
                        }
                        setDs(() => loading = true);
                        try {
                          await _apiService.setPassword(
                            currentPassword: currentCtrl.text,
                            newPassword: newCtrl.text,
                            confirmPassword: confirmCtrl.text,
                          );
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(_t('Password changed!', 'تم التغيير!')),
                                backgroundColor: AppColors.primary));
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: Colors.red));
                        } finally {
                          if (mounted) setDs(() => loading = false);
                        }
                      },
                      child: loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_t('Update Password', 'تحديث كلمة المرور'),
                              style: const TextStyle(color: Colors.white)),
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

  Widget _pwField(TextEditingController ctrl, String label, bool obscure, IconData icon, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: toggle),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  void _showDeactivateDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(_t('Deactivate Account', 'تعطيل الحساب'),
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.red)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  _t('This will deactivate the entire family account. All members will be logged out.',
                      'سيتم تعطيل حساب العائلة بالكامل وتسجيل خروج جميع الأعضاء.'),
                  style: GoogleFonts.poppins(fontSize: _sp(11), color: Colors.red),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: _t('Email', 'البريد الإلكتروني'),
                  prefixIcon: const Icon(Icons.email, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _t('Password', 'كلمة المرور'),
                  prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Cancel', 'إلغاء'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: loading ? null : () async {
                if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) return;
                setDs(() => loading = true);
                try {
                  await _apiService.deactivateAccount(emailCtrl.text.trim(), passCtrl.text);
                  if (mounted) {
                    Navigator.pop(ctx);
                    await Future.delayed(const Duration(milliseconds: 400));
                    _handleLogoutCurrent();
                  }
                } catch (e) {
                  setDs(() => loading = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red));
                }
              },
              child: loading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_t('Deactivate', 'تعطيل')),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: const AppBottomNav(selectedIndex: 4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildProfileCard(),
                  const SizedBox(height: 20),

                  _buildSection(label: _t('MY ACCOUNT', 'حسابي'), rows: [
                    _buildRow(icon: Icons.person_outline, iconBg: AppColors.primarySurface, iconColor: AppColors.primary,
                        title: _t('Edit Profile', 'تعديل الملف الشخصي'),
                        subtitle: _currentUsername.isNotEmpty ? _currentUsername : null,
                        onTap: _showEditProfileDialog),
                    _buildRow(icon: Icons.group_outlined, iconBg: const Color(0xFFE8F5E9), iconColor: const Color(0xFF2E7D32),
                        title: _t('Family Members', 'أفراد العائلة'),
                        subtitle: _membersLoading ? null : '${_familyMembers.length} ${_t('members', 'أعضاء')}',
                        onTap: _showFamilyMembersSheet),
                    _buildRow(icon: Icons.lock_outline, iconBg: const Color(0xFFFFF8E1), iconColor: const Color(0xFFF9A825),
                        title: _t('Change Password', 'تغيير كلمة المرور'), onTap: _showChangePasswordDialog),
                    _buildRow(icon: Icons.swap_horiz, iconBg: const Color(0xFFE3F2FD), iconColor: const Color(0xFF1565C0),
                        title: _t('Switch Profile', 'تبديل الحساب'),
                        subtitle: '${_savedProfiles.length} ${_t('saved', 'محفوظ')}',
                        onTap: _showSwitchProfileDialog),
                  ]),

                  if (_isParent) ...[
                    const SizedBox(height: 16),
                    _buildSection(label: _t('FAMILY SETTINGS', 'إعدادات العائلة'), rows: [
                      _buildRow(
                        icon: Icons.currency_exchange,
                        iconBg: const Color(0xFFE8F5E9), iconColor: const Color(0xFF2E7D32),
                        title: _t('Conversion Rates', 'أسعار التحويل'),
                        subtitle: '1 EGP = ${_moneyToPointsRate.toStringAsFixed(0)} pts  •  100 pts = ${(_pointsToMoneyRate * 100).toStringAsFixed(0)} EGP',
                        onTap: _showConversionRateDialog,
                      ),
                    ]),
                  ],

                  const SizedBox(height: 16),
                  _buildSection(label: _t('PREFERENCES', 'التفضيلات'), rows: [
                    _buildToggleRow(
                      icon: Icons.notifications_outlined,
                      iconBg: const Color(0xFFFFF3E0), iconColor: const Color(0xFFE65100),
                      title: _t('Notifications', 'الإشعارات'),
                      subtitle: _notificationsEnabled ? _t('Enabled', 'مفعّل') : _t('Disabled', 'معطّل'),
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                    ),
                    _buildRow(icon: Icons.language, iconBg: AppColors.primarySurface, iconColor: AppColors.primary,
                        title: _t('Language', 'اللغة'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
                          child: Text(_languageCode == 'ar' ? 'عر' : 'EN',
                              style: GoogleFonts.poppins(fontSize: _sp(12), color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                        onTap: _showLanguageDialog),
                    _buildToggleRow(
                      icon: isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                      iconBg: isDark ? const Color(0xFF1A1A2E) : AppColors.primarySurface,
                      iconColor: isDark ? Colors.white : AppColors.primary,
                      title: _t('Dark Mode', 'الوضع الداكن'),
                      subtitle: isDark ? _t('On', 'مفعّل') : _t('Off', 'معطّل'),
                      value: isDark,
                      onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                    ),
                    _buildToggleRow(
                      icon: Icons.location_on_outlined, iconBg: AppColors.primarySurface, iconColor: AppColors.primary,
                      title: _isUpdatingLocationSharing
                          ? _t('Location Sharing (updating…)', 'مشاركة الموقع (جارٍ التحديث…)')
                          : _t('Location Sharing', 'مشاركة الموقع'),
                      subtitle: _locationSharing
                          ? _t('Visible to family', 'مرئي للعائلة')
                          : _t('Hidden from map', 'مخفي عن الخريطة'),
                      value: _locationSharing,
                      onChanged: _toggleLocationSharingFromSettings,
                    ),
                    _buildThemePickerRow(isDark),
                  ]),

                  const SizedBox(height: 16),
                  _buildSection(label: _t('SUPPORT', 'الدعم'), rows: [
                    _buildRow(icon: Icons.help_outline, iconBg: const Color(0xFFE0F7FA), iconColor: const Color(0xFF00838F),
                        title: _t('Help Center', 'مركز المساعدة'), onTap: () {}),
                    _buildRow(icon: Icons.mail_outline, iconBg: const Color(0xFFFCE4EC), iconColor: const Color(0xFFAD1457),
                        title: _t('Contact Us', 'تواصل معنا'), onTap: () {}),
                    _buildRow(icon: Icons.info_outline, iconBg: AppColors.primarySurface, iconColor: AppColors.primary,
                        title: _t('About Family Hub', 'عن فاميلي هب'), onTap: () {}),
                  ]),

                  const SizedBox(height: 16),
                  _buildDangerZone(),
                  const SizedBox(height: 20),
                  _buildLogoutButton(),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Text('Family Hub v1.0.0',
                            style: GoogleFonts.poppins(fontSize: _sp(11), color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        Text("Made with ❤️ by Samia's Team",
                            style: GoogleFonts.poppins(fontSize: _sp(10), color: AppColors.textHint)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final initial = _familyTitle.isNotEmpty ? _familyTitle[0].toUpperCase() : 'F';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Stack(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                  child: Center(child: Text(initial,
                      style: GoogleFonts.poppins(fontSize: _sp(22), fontWeight: FontWeight.w800, color: Colors.white))),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                    child: const Icon(Icons.edit, size: 11, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _familyTitle.isNotEmpty
                      ? _t('$_familyTitle Family', 'عائلة $_familyTitle')
                      : _t('Family', 'العائلة'),
                  style: GoogleFonts.poppins(fontSize: _sp(15), fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (_currentUsername.isNotEmpty)
                  Text('@$_currentUsername',
                      style: GoogleFonts.poppins(fontSize: _sp(11), color: Colors.white.withOpacity(0.8))),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _isParent ? '👑 ${_t("Parent", "أحد الوالدين")}' : '👤 ${_t("Member", "عضو")}',
                    style: GoogleFonts.poppins(fontSize: _sp(10), color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String label, required List<Widget> rows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: _sp(10), fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          decoration: _cardDecoration(),
          child: Column(
            children: rows.asMap().entries.map((e) {
              final isLast = e.key == rows.length - 1;
              return Column(children: [
                e.value,
                if (!isLast) const Divider(height: 1, thickness: 0.5, color: AppColors.borderLight, indent: 54),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: iconColor, size: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: _sp(13), fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: _sp(10), color: AppColors.textSecondary),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon, required Color iconBg, required Color iconColor,
    required String title, String? subtitle,
    required bool value, required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: _sp(13), fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                if (subtitle != null)
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: _sp(10), color: AppColors.textSecondary)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: _isUpdatingLocationSharing ? null : onChanged,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primarySurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePickerRow(bool isDark) {
    final options = [
      (AppColors.primary, ThemeMode.light, !isDark),
      (const Color(0xFF43A047), ThemeMode.light, false),
      (const Color(0xFF7B1FA2), ThemeMode.light, false),
      (AppColors.darkBg, ThemeMode.dark, isDark),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(width: 32, height: 32,
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.palette_outlined, color: AppColors.primary, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Text(_t('App Theme', 'سمة التطبيق'),
              style: GoogleFonts.poppins(fontSize: _sp(13), fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          Row(
            children: options.map((opt) {
              final color = opt.$1;
              final mode = opt.$2;
              final isSelected = opt.$3;
              return GestureDetector(
                onTap: () => context.read<ThemeProvider>().setTheme(mode),
                child: Container(
                  margin: const EdgeInsets.only(left: 7),
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: color,
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2.5),
                    boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 4)] : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: InkWell(
        onTap: _showDeactivateDialog,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: AppColors.errorSurface, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.exit_to_app, color: AppColors.error, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_t('Deactivate Family Account', 'تعطيل حساب العائلة'),
                      style: GoogleFonts.poppins(fontSize: _sp(13), fontWeight: FontWeight.w500, color: AppColors.error)),
                  Text(_t('Cannot be undone', 'لا يمكن التراجع'),
                      style: GoogleFonts.poppins(fontSize: _sp(10), color: Colors.red.withOpacity(0.6))),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFFFCDD2), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(_t('Logout options', 'خيارات تسجيل الخروج')),
            content: Text(_t('Choose whether to logout this profile only or all saved profiles.',
                'اختر تسجيل خروج الحساب الحالي فقط أو كل الحسابات المحفوظة.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t('Cancel', 'إلغاء'))),
              TextButton(onPressed: () async { Navigator.pop(ctx); await _handleLogoutCurrent(); },
                  child: Text(_t('Logout current', 'خروج الحساب الحالي'))),
              TextButton(onPressed: () async { Navigator.pop(ctx); await _handleLogoutAll(); },
                  child: Text(_t('Logout all', 'خروج الكل'), style: const TextStyle(color: Colors.red))),
            ],
          ),
        ),
        icon: const Icon(Icons.logout_outlined, color: AppColors.primary),
        label: Text(_t('Logout Options', 'خيارات تسجيل الخروج'),
            style: GoogleFonts.poppins(fontSize: _sp(14), fontWeight: FontWeight.w600, color: AppColors.primary)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
