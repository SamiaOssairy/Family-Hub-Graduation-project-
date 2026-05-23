import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FutureEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(double) onUpdateSaved;
  final VoidCallback? onOpenFunding;

  const FutureEventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onUpdateSaved,
    this.onOpenFunding,
  });

  @override
  Widget build(BuildContext context) {
    final estimated = (event['estimated_cost'] ?? 0).toDouble();
    final saved = (event['saved_amount'] ?? 0).toDouble();
    final progress = estimated > 0 ? (saved / estimated).clamp(0.0, 1.0) : 0.0;
    final shouldRemind = event['should_remind'] == true;
    final monthsUntil = event['months_until_event'] ?? 0;
    final suggestedSaving = (event['suggested_saving_amount'] ?? 0).toDouble();
    final isCompleted = event['is_completed'] == true;
    final expDate = event['expected_date'] != null ? DateTime.parse(event['expected_date']) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: shouldRemind && !isCompleted ? Border.all(color: Colors.orange.shade400, width: 2) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  event['name'] ?? '',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (shouldRemind && !isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Reminder',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ]),
            if (expDate != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(DateFormat('dd MMM yyyy').format(expDate), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                Icon(Icons.schedule, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '$monthsUntil months away',
                  style: TextStyle(
                    color: monthsUntil <= 3 ? Colors.orange : Colors.grey,
                    fontSize: 13,
                    fontWeight: monthsUntil <= 3 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : const Color(0xFF00897B)),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Saved: \$${saved.toStringAsFixed(0)} / \$${estimated.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: progress >= 1.0 ? Colors.green : const Color(0xFF00897B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ]),
            if (suggestedSaving > 0 && !isCompleted) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFE8F5F5), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.lightbulb_outline, color: Color(0xFF00897B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggest saving \$${suggestedSaving.toStringAsFixed(2)} per ${event['saving_frequency'] ?? 'month'}',
                      style: const TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                  ),
                ]),
              ),
            ],
            if (onOpenFunding != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenFunding,
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Open Funding Details'),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
