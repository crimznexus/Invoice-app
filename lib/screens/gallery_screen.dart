import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/invoice.dart';
import '../widgets/invoice_card.dart';
import 'invoice_form_screen.dart';
import 'invoice_preview_screen.dart';
import 'manage_products_screen.dart';

final _money = NumberFormat('#,##0.00', 'en_PK');

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _db = DbHelper();
  List<Invoice> _all = [];
  List<Invoice> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final invoices = await _db.getAllInvoices();
    setState(() {
      _all = invoices;
      _filtered = invoices;
      _loading = false;
    });
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all.where((inv) =>
              inv.invoiceNumber.toLowerCase().contains(q) ||
              inv.customerName.toLowerCase().contains(q) ||
              inv.salesRep.toLowerCase().contains(q)).toList();
    });
  }

  Future<void> _delete(Invoice inv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
            'Delete Invoice #${inv.invoiceNumber} for ${inv.customerName}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && inv.id != null) {
      await _db.deleteInvoice(inv.id!);
      _load();
    }
  }

  Future<void> _goToForm({Invoice? editing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => InvoiceFormScreen(editing: editing)),
    );
    _load();
  }

  void _goToPreview(Invoice inv) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: inv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _all.fold(0.0, (s, i) => s + i.total);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo.png'),
        ),
        title: const Text('Moosjan Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined,
                color: Colors.white70),
            tooltip: 'Manage Products',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ManageProductsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Stats bar ─────────────────────────
                Container(
                  color: kSidebar,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      _statChip(
                        '${_all.length}',
                        'Invoices',
                        Icons.receipt_long_outlined,
                      ),
                      const SizedBox(width: 12),
                      _statChip(
                        'PKR ${_money.format(totalRevenue)}',
                        'Total Revenue',
                        Icons.attach_money,
                      ),
                    ],
                  ),
                ),

                // ── Search ────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by customer, invoice #, rep…',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: kMuted),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: kMuted),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18, color: kMuted),
                              onPressed: () {
                                _searchCtrl.clear();
                                _filter();
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // ── Invoice list ──────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 100),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final inv = _filtered[i];
                              return InvoiceCard(
                                invoice: inv,
                                onTap: () => _goToPreview(inv),
                                onEdit: () => _goToForm(editing: inv),
                                onDelete: () => _delete(inv),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _goToForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }

  Widget _statChip(String value, String label, IconData icon) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
              ],
            ),
          ],
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _all.isEmpty
                  ? 'No invoices yet'
                  : 'No results found',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500),
            ),
            if (_all.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Tap + New Invoice to get started',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[400])),
            ],
          ],
        ),
      );
}
