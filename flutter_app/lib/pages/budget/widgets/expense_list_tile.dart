import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseListTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseListTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final amount = (expense['amount'] ?? 0).toDouble();
    final isEmergency = expense['is_emergency'] == true;
    final hasPhoto = expense['receipt_photo_url'] != null &&
        expense['receipt_photo_url'].toString().isNotEmpty;
    final date = expense['expense_date'] != null
        ? DateTime.parse(expense['expense_date'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isEmergency ? Colors.orange.shade100 : const Color(0xFFE8F5F5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEmergency ? Icons.emergency : Icons.receipt_long,
            color: isEmergency ? Colors.orange : const Color(0xFF00897B),
            size: 22,
          ),
        ),
        title: Row(children: [
          Expanded(child: Text(
            expense['description']?.isNotEmpty == true
                ? expense['description']
                : expense['category_name'] ?? 'Expense',
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          )),
          if (hasPhoto)
            Icon(Icons.photo, size: 14, color: Colors.grey),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expense['category_name'] ?? '',
              style: const TextStyle(fontSize: 12)),
          if (date != null)
            Text(DateFormat('dd/MM/yyyy').format(date),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (isEmergency)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Emergency',
                  style: TextStyle(fontSize: 10, color: Colors.orange,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('-\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline, size: 18, color: Colors.grey),
            ),
        ]),
      ),
    );
  }
}