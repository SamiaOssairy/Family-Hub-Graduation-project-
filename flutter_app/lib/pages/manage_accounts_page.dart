import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/localization/app_i18n.dart';

class ManageAccountsPage extends StatefulWidget {
  const ManageAccountsPage({super.key});

  @override
  State<ManageAccountsPage> createState() => _ManageAccountsPageState();
}

class _ManageAccountsPageState extends State<ManageAccountsPage> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _profiles = [];
  String _activeProfileKey = '';
  bool _loading = true;
  bool _changed = false;

  String _t(String en, String ar) => AppI18n.t(context, en, ar);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profiles = await _apiService.getSavedProfiles();
    final active = await _apiService.getActiveProfileKey() ?? '';
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeProfileKey = active;
      _loading = false;
    });
  }

  Future<void> _switchProfile(String profileKey) async {
    try {
      await _apiService.switchProfile(profileKey);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Account switched', 'تم تبديل الحساب'))),
      );
      _changed = true;
      Navigator.of(context).pop(true);
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

  Future<void> _removeProfile(String profileKey) async {
    try {
      await _apiService.removeSavedProfile(profileKey);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Account removed', 'تم حذف الحساب'))),
      );
      _changed = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_t('Failed to remove account', 'فشل حذف الحساب')}: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final rawNewIndex = newIndex;
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _profiles.removeAt(oldIndex);
      _profiles.insert(newIndex, item);
    });

    await _apiService.reorderSavedProfiles(oldIndex, rawNewIndex);
    await _loadData();
    _changed = true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_changed);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('Manage Accounts', 'إدارة الحسابات')),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator())
            : _profiles.isEmpty
                ? Center(
                    child: Text(_t('No saved accounts', 'لا توجد حسابات محفوظة')),
                  )
                : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _profiles.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    final profileKey = profile['profileKey']?.toString() ?? '';
                    final familyTitle = profile['familyTitle']?.toString() ?? _t('Family', 'العائلة');
                    final username = profile['username']?.toString() ?? _t('Member', 'عضو');
                    final mail = profile['mail']?.toString() ?? '';
                    final isActive = profileKey == _activeProfileKey;

                    return Card(
                      key: ValueKey(profileKey),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isActive)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_circle, color: Color(0xFF00897B)),
                              ),
                            IconButton(
                              tooltip: _t('Switch account', 'تبديل الحساب'),
                              icon: Icon(Icons.swap_horiz),
                              onPressed: isActive ? null : () => _switchProfile(profileKey),
                            ),
                            IconButton(
                              tooltip: _t('Remove account', 'حذف الحساب'),
                              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(_t('Remove account?', 'حذف الحساب؟')),
                                    content: Text(_t(
                                      'Remove $familyTitle ($username) from this device?',
                                      'حذف $familyTitle ($username) من هذا الجهاز؟',
                                    )),
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
                                  ),
                                );

                                if (confirmed == true) {
                                  await _removeProfile(profileKey);
                                }
                              },
                            ),
                            Icon(Icons.drag_handle),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
