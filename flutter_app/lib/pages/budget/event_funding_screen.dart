import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:app_frontend/core/services/api_service.dart';
import 'package:app_frontend/core/widgets/guarded_button.dart';

class EventFundingScreen extends StatefulWidget {
  const EventFundingScreen({super.key});

  @override
  State<EventFundingScreen> createState() => _EventFundingScreenState();
}

class _EventFundingScreenState extends State<EventFundingScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isParent = false;
  bool _isAutoSaveEnabled = false;

  String? _eventId;
  Map<String, dynamic> _funding = {};
  List<Map<String, dynamic>> _members = [];

  int _myPoints = 0;

  TabController? _tabController;
  List<_FundingTab> _tabs = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_eventId != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final mapped = Map<String, dynamic>.from(args);
      _eventId = (mapped['eventId'] ?? mapped['event_id'])?.toString();
    }

    if (_eventId == null || _eventId!.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_eventId == null || _eventId!.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      _isParent = await _apiService.isParent();

      final results = await Future.wait([
        _apiService.getEventFundingStatus(_eventId!),
        _apiService.getMyWallet(),
      ]);

      final funding = Map<String, dynamic>.from(results[0]);
      final wallet = Map<String, dynamic>.from(results[1]);

      List<Map<String, dynamic>> members = [];
      if (_isParent) {
        final membersRaw = await _apiService.getAllMembers();
        members = membersRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      _setupTabs(funding);

      if (!mounted) return;
      setState(() {
        _funding = funding;
        _myPoints = (wallet['total_points'] ?? 0) as int;
        _members = members;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load event funding: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _setupTabs(Map<String, dynamic> funding) {
    final source = (funding['funding_source'] ?? '').toString();
    final requiredPoints = ((funding['required_points'] ?? 0) as num).toDouble();

    final tabs = <_FundingTab>[];

    if (source == 'budget') {
      tabs.add(const _FundingTab(id: 'budget', title: 'Family Budget'));
    }

    if (source == 'member_contributions' || source == 'budget') {
      tabs.add(const _FundingTab(id: 'contributions', title: 'Member Contributions'));
    }

    if (requiredPoints > 0 || source == 'points_redeem') {
      tabs.add(const _FundingTab(id: 'points', title: 'Points Redemption'));
    }

    if (tabs.isEmpty) {
      tabs.add(const _FundingTab(id: 'contributions', title: 'Member Contributions'));
    }

    _tabController?.dispose();
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabs = tabs;
  }

  Future<void> _showContributeSheet({Map<String, dynamic>? member}) async {
    if (_eventId == null || _eventId!.isEmpty) return;

    final amountController = TextEditingController();
    String contributionType = 'money';
    String paymentMode = 'pay_now';
    String? selectedMemberId = member?['member_id']?.toString();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final canPickMember = _isParent;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      member == null ? 'Add Contribution' : 'Contribute for ${member['member_name'] ?? 'Member'}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    if (canPickMember) ...[
                      Text('Member', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedMemberId,
                        items: _members
                            .map(
                              (m) => DropdownMenuItem<String>(
                                value: m['_id']?.toString(),
                                child: Text((m['username'] ?? m['mail'] ?? 'Member').toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setSheetState(() => selectedMemberId = value),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Use points instead?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Money'),
                          selected: contributionType == 'money',
                          onSelected: (_) => setSheetState(() => contributionType = 'money'),
                        ),
                        ChoiceChip(
                          label: const Text('Points'),
                          selected: contributionType == 'points',
                          onSelected: (_) => setSheetState(() => contributionType = 'points'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Contribution Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Pay now'),
                          selected: paymentMode == 'pay_now',
                          onSelected: (_) => setSheetState(() => paymentMode = 'pay_now'),
                        ),
                        ChoiceChip(
                          label: const Text('Promise to pay later'),
                          selected: paymentMode == 'promise',
                          onSelected: (_) => setSheetState(() => paymentMode = 'promise'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GuardedElevatedButton(
                        onPressed: () async {
                          final amount = double.tryParse(amountController.text.trim());
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please enter a valid amount')),
                            );
                            return;
                          }

                          if (_isParent && (selectedMemberId == null || selectedMemberId!.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please select a member')),
                            );
                            return;
                          }

                          try {
                            await _apiService.contributeToEvent(
                              _eventId!,
                              contributionType: contributionType,
                              amount: amount,
                              paymentMode: paymentMode,
                              memberId: selectedMemberId,
                              manualEntry: _isParent && paymentMode == 'pay_now',
                            );

                            if (!mounted) return;
                            Navigator.pop(context);
                            await _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Contribution saved'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Contribution failed: $e'), backgroundColor: Colors.red),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Save Contribution', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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

  Future<void> _markPaid(Map<String, dynamic> memberRow) async {
    if (_eventId == null || _eventId!.isEmpty) return;

    final amountController = TextEditingController();
    String type = 'money';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
              title: Text('Mark as Paid', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Member: ${memberRow['member_name'] ?? 'Member'}',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount to mark paid',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Money'),
                        selected: type == 'money',
                        onSelected: (_) => setDialog(() => type = 'money'),
                      ),
                      ChoiceChip(
                        label: const Text('Points'),
                        selected: type == 'points',
                        onSelected: (_) => setDialog(() => type = 'points'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return;

    try {
      await _apiService.markEventContributionPaid(
        _eventId!,
        memberId: (memberRow['member_id'] ?? '').toString(),
        contributionType: type,
        amount: amount,
      );

      if (!mounted) return;
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as paid'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark paid: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _adjustFundingGoal() async {
    if (_eventId == null || _eventId!.isEmpty) return;

    final estimated = ((_funding['total_estimated_cost'] ?? 0) as num).toDouble();
    final controller = TextEditingController(text: estimated.toStringAsFixed(0));

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Adjust Funding Goal', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Estimated Cost',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    final nextValue = double.tryParse(controller.text.trim());
    if (nextValue == null || nextValue < 0) return;

    try {
      await _apiService.adjustEventFundingGoal(_eventId!, nextValue);
      if (!mounted) return;
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Funding goal updated'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _redeemSpot() async {
    if (_eventId == null || _eventId!.isEmpty) return;

    final requiredPoints = ((_funding['required_points'] ?? 0) as num).toDouble();

    if (requiredPoints <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No points requirement found for this event')),
      );
      return;
    }

    try {
      await _apiService.redeemEventSpot(eventId: _eventId!, pointsToUse: requiredPoints);
      if (!mounted) return;
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Spot redeemed successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redeem failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        title: Text('Event Funding', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : (_eventId == null || _eventId!.isEmpty)
              ? _buildErrorState('Missing event ID')
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final title = (_funding['event_title'] ?? 'Event').toString();
    final eventDateRaw = _funding['event_date']?.toString();
    final eventDate = eventDateRaw != null ? DateTime.tryParse(eventDateRaw) : null;
    final totalCost = ((_funding['total_estimated_cost'] ?? 0) as num).toDouble();
    final progressPct = ((_funding['progress_percentage'] ?? 0) as num).toDouble();
    final daysRemaining = ((_funding['days_remaining'] ?? 0) as num).toInt();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(
            title: title,
            eventDate: eventDate,
            totalCost: totalCost,
            progressPct: progressPct,
            daysRemaining: daysRemaining,
          ),
          const SizedBox(height: 14),
          if (_tabController != null && _tabs.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF00897B),
                unselectedLabelColor: Colors.grey[700],
                indicatorColor: const Color(0xFF00897B),
                tabs: _tabs.map((t) => Tab(text: t.title)).toList(),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 620,
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                if (tab.id == 'budget') return _buildBudgetTab();
                if (tab.id == 'points') return _buildPointsTab();
                return _buildContributionsTab();
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard({
    required String title,
    required DateTime? eventDate,
    required double totalCost,
    required double progressPct,
    required int daysRemaining,
  }) {
    final totalContributed = ((_funding['total_contributed_money'] ?? 0) as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      eventDate != null
                          ? 'Date: ${DateFormat('dd MMM yyyy').format(eventDate)}'
                          : 'Date: -',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                    Text(
                      'Estimated Cost: ${totalCost.toStringAsFixed(2)} EGP',
                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              if (_isParent)
                IconButton(
                  onPressed: _adjustFundingGoal,
                  icon: Icon(Icons.tune, color: Colors.white),
                  tooltip: 'Adjust Funding Goal',
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (progressPct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${progressPct.toStringAsFixed(1)}% funded',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${totalContributed.toStringAsFixed(2)} EGP raised',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$daysRemaining days remaining',
            style: GoogleFonts.poppins(
              color: daysRemaining <= 7 ? Colors.orange.shade100 : Colors.white70,
              fontWeight: daysRemaining <= 7 ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetTab() {
    final monthly = ((_funding['monthly_savings_needed'] ?? 0) as num).toDouble();
    final remaining = ((_funding['remaining_needed'] ?? 0) as num).toDouble();
    final rewardsBudget = _funding['rewards_budget_remaining'];

    return ListView(
      children: [
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Savings Plan', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _infoRow('Remaining needed', '${remaining.toStringAsFixed(2)} EGP'),
              _infoRow('Monthly savings needed', '${monthly.toStringAsFixed(2)} EGP / month'),
              if (rewardsBudget != null)
                _infoRow('Rewards budget remaining', '${(rewardsBudget as num).toStringAsFixed(2)} EGP'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isAutoSaveEnabled = !_isAutoSaveEnabled);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isAutoSaveEnabled
                            ? 'Auto-Save enabled (UI toggle)'
                            : 'Auto-Save disabled'),
                      ),
                    );
                  },
                  icon: Icon(_isAutoSaveEnabled ? Icons.check_circle : Icons.savings),
                  label: Text(_isAutoSaveEnabled ? 'Auto-Save Enabled' : 'Set Auto-Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContributionsTab() {
    final breakdownRaw = _funding['breakdown_by_member'];
    final rows = (breakdownRaw is List)
        ? breakdownRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return ListView(
      children: [
        if (_isParent)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ElevatedButton.icon(
              onPressed: () => _showContributeSheet(),
              icon: Icon(Icons.add),
              label: const Text('Add Contribution'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (rows.isEmpty)
          _buildPanel(
            child: Text(
              'No contributions yet.',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          )
        else
          ...rows.map(_buildMemberContributionCard),
      ],
    );
  }

  Widget _buildMemberContributionCard(Map<String, dynamic> row) {
    final promisedMoney = ((row['amount_promised'] ?? 0) as num).toDouble();
    final paidMoney = ((row['amount_paid'] ?? 0) as num).toDouble();
    final promisedPoints = ((row['points_promised'] ?? 0) as num).toDouble();
    final paidPoints = ((row['points_paid'] ?? 0) as num).toDouble();

    final totalTarget = promisedMoney + paidMoney + promisedPoints + paidPoints;
    final done = paidMoney + paidPoints;
    final progress = totalTarget <= 0 ? 0.0 : (done / totalTarget).clamp(0.0, 1.0);

    return _buildPanel(
      marginBottom: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (row['member_name'] ?? 'Member').toString(),
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              OutlinedButton(
                onPressed: () => _showContributeSheet(member: row),
                child: const Text('Contribute'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _infoRow('Promised amount', '${promisedMoney.toStringAsFixed(2)} EGP'),
          _infoRow('Paid amount', '${paidMoney.toStringAsFixed(2)} EGP'),
          _infoRow('Promised points', '${promisedPoints.toStringAsFixed(0)} pts'),
          _infoRow('Paid points', '${paidPoints.toStringAsFixed(0)} pts'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00897B)),
          ),
          const SizedBox(height: 6),
          Text(
            'Progress per member: ${(progress * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
          ),
          if (_isParent && (promisedMoney > 0 || promisedPoints > 0))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _markPaid(row),
                icon: Icon(Icons.check_circle_outline),
                label: const Text('Mark as Paid'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPointsTab() {
    final cost = ((_funding['required_points'] ?? 0) as num).toDouble();
    final redeemedRaw = _funding['members_redeemed_spots'];
    final redeemed = (redeemedRaw is List)
        ? redeemedRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    return ListView(
      children: [
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buy Your Spot', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Cost: ${cost.toStringAsFixed(0)} Points', style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 4),
              Text('Current points balance: $_myPoints', style: GoogleFonts.poppins(color: Colors.grey[700])),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GuardedElevatedButton(
                  onPressed: _myPoints >= cost ? _redeemSpot : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Redeem Spot'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Members Who Redeemed Spots', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (redeemed.isEmpty)
                Text('No spots redeemed yet.', style: GoogleFonts.poppins(color: Colors.grey[700]))
              else
                ...redeemed.map((r) {
                  final mail = (r['member_mail'] ?? 'Member').toString();
                  final pointsUsed = ((r['points_used'] ?? 0) as num).toDouble();
                  final redeemedAtRaw = r['redeemed_at']?.toString();
                  final redeemedAt = redeemedAtRaw != null ? DateTime.tryParse(redeemedAtRaw) : null;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5F5),
                      child: Icon(Icons.person, color: Color(0xFF00897B)),
                    ),
                    title: Text(mail, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      redeemedAt != null ? DateFormat('dd MMM, HH:mm').format(redeemedAt) : 'Unknown date',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    trailing: Text(
                      '${pointsUsed.toStringAsFixed(0)} pts',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.red[700]),
        ),
      ),
    );
  }

  Widget _buildPanel({required Widget child, double marginBottom = 0}) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: GoogleFonts.poppins(color: Colors.grey[700]))),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FundingTab {
  final String id;
  final String title;

  const _FundingTab({required this.id, required this.title});
}
