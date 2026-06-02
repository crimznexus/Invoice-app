import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/invoice.dart';

final _money = NumberFormat('#,##0.00', 'en_PK');

class InvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const InvoiceCard({
    super.key,
    required this.invoice,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  String get _dateDisplay {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(invoice.date));
    } catch (_) {
      return invoice.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: kBlueLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${invoice.invoiceNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kBlue,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _dateDisplay,
                    style: const TextStyle(
                        fontSize: 11, color: kMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                invoice.customerName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: kText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (invoice.salesRep.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Rep: ${invoice.salesRep}',
                  style:
                      const TextStyle(fontSize: 11, color: kMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'PKR ${_money.format(invoice.total)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kGreenDark,
                ),
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                        foregroundColor: kBlue,
                        side: const BorderSide(color: Color(0xFFDDE2EA)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(fontSize: 12),
                        foregroundColor: Colors.red,
                        side: const BorderSide(
                            color: Color(0xFFFFCCCC)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
