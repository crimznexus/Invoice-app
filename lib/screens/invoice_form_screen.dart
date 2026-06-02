import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../database/db_helper.dart';
import '../models/invoice.dart';
import 'invoice_preview_screen.dart';
import 'manage_products_screen.dart';

// ── Item row state ────────────────────────────────────────
class _ItemEntry {
  String itemName = '';
  bool isManual = false; // true = user typed manually
  final TextEditingController manualCtrl = TextEditingController();
  final TextEditingController qtyCtrl    = TextEditingController();
  final TextEditingController priceCtrl  = TextEditingController();

  _ItemEntry({InvoiceItem? from}) {
    if (from != null) {
      itemName      = from.itemName;
      isManual      = true;
      manualCtrl.text = from.itemName;
      qtyCtrl.text  = _fmt(from.quantity);
      priceCtrl.text = _fmt(from.priceEach);
    }
  }

  static String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  double get qty    => double.tryParse(qtyCtrl.text)   ?? 0;
  double get price  => double.tryParse(priceCtrl.text) ?? 0;
  double get amount => qty * price;

  String get effectiveName =>
      isManual ? manualCtrl.text.trim() : itemName.trim();

  InvoiceItem toItem() => InvoiceItem(
        itemName: effectiveName,
        description: effectiveName,
        quantity: qty,
        priceEach: price,
        amount: amount,
      );

  void dispose() {
    manualCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────
class InvoiceFormScreen extends StatefulWidget {
  final Invoice? editing;
  const InvoiceFormScreen({super.key, this.editing});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _db = DbHelper();
  final _scrollCtrl = ScrollController();

  final _invoiceNoCtrl   = TextEditingController();
  final _salesRepCtrl    = TextEditingController();
  final _custNameCtrl    = TextEditingController();
  final _custAddressCtrl = TextEditingController();
  final _notesCtrl       = TextEditingController();
  String _date = '';

  final List<_ItemEntry> _items = [];
  List<Product> _products = [];
  bool _saving = false;

  final _moneyFmt = NumberFormat('#,##0.00', 'en_PK');
  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _products = await _db.getAllProducts();

    if (_isEditing) {
      final inv = widget.editing!;
      _invoiceNoCtrl.text   = inv.invoiceNumber;
      _salesRepCtrl.text    = inv.salesRep;
      _custNameCtrl.text    = inv.customerName;
      _custAddressCtrl.text = inv.customerAddress;
      _notesCtrl.text       = inv.notes;
      _date                 = inv.date;
      for (final item in inv.items) {
        _items.add(_ItemEntry(from: item));
      }
    } else {
      _date = DateTime.now().toIso8601String().split('T').first;
      final nextNum = await _db.getNextInvoiceNumber();
      if (mounted) _invoiceNoCtrl.text = nextNum.toString();
    }

    if (_items.isEmpty) _items.add(_ItemEntry());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _invoiceNoCtrl.dispose();
    _salesRepCtrl.dispose();
    _custNameCtrl.dispose();
    _custAddressCtrl.dispose();
    _notesCtrl.dispose();
    for (final e in _items) e.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (s, e) => s + e.amount);

  void _addItem() {
    setState(() => _items.add(_ItemEntry()));
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  Future<void> _pickDate() async {
    DateTime initial;
    try { initial = DateTime.parse(_date); } catch (_) { initial = DateTime.now(); }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _date = picked.toIso8601String().split('T').first);
    }
  }

  String get _dateDisplay {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(_date));
    } catch (_) {
      return _date.isEmpty ? 'Tap to select' : _date;
    }
  }

  // ── Product picker bottom sheet ───────────────────────
  Future<void> _pickProduct(int index) async {
    // Refresh product list in case user just added one
    _products = await _db.getAllProducts();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(
        products: _products,
        onProductSelected: (name) {
          setState(() {
            _items[index].itemName = name;
            _items[index].isManual = false;
            _items[index].manualCtrl.text = '';
          });
          Navigator.pop(ctx);
        },
        onManualSelected: () {
          setState(() {
            _items[index].isManual = true;
            _items[index].itemName = '';
          });
          Navigator.pop(ctx);
        },
        onManageProducts: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageProductsScreen()),
          ).then((_) async {
            _products = await _db.getAllProducts();
            setState(() {});
          });
        },
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────
  Future<void> _save({bool preview = false}) async {
    if (_invoiceNoCtrl.text.trim().isEmpty) {
      _snack('Please enter an invoice number.');
      return;
    }
    if (_custNameCtrl.text.trim().isEmpty) {
      _snack('Please enter a customer name.');
      return;
    }
    final validItems =
        _items.where((e) => e.effectiveName.isNotEmpty).toList();
    if (validItems.isEmpty) {
      _snack('Please add at least one item with a product description.');
      return;
    }

    setState(() => _saving = true);

    final invoice = Invoice(
      id: _isEditing ? widget.editing!.id : null,
      invoiceNumber: _invoiceNoCtrl.text.trim(),
      date: _date,
      salesRep: _salesRepCtrl.text.trim(),
      customerName: _custNameCtrl.text.trim(),
      customerAddress: _custAddressCtrl.text.trim(),
      items: validItems.map((e) => e.toItem()).toList(),
      total: _total,
      notes: _notesCtrl.text.trim(),
      createdAt: _isEditing
          ? widget.editing!.createdAt
          : DateTime.now().toIso8601String(),
    );

    Invoice saved;
    if (_isEditing) {
      await _db.updateInvoice(invoice);
      saved = invoice;
    } else {
      saved = await _db.insertInvoice(invoice);
    }

    setState(() => _saving = false);
    if (!mounted) return;

    if (preview) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: saved)),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? 'Edit #${widget.editing!.invoiceNumber}'
            : 'New Invoice'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(preview: true),
            child: const Text('Preview',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [

          // ── Invoice Details ────────────────────────
          _card(
            title: 'Invoice Details',
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceNoCtrl,
                    decoration: const InputDecoration(labelText: 'Invoice #'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(_dateDisplay,
                          style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _salesRepCtrl,
                decoration:
                    const InputDecoration(labelText: 'Sales Representative'),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Bill To ───────────────────────────────
          _card(
            title: 'Bill To',
            child: Column(children: [
              TextField(
                controller: _custNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Customer Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _custAddressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Items ─────────────────────────────────
          _card(
            title: 'Items',
            trailing: TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(foregroundColor: kBlue),
            ),
            child: Column(children: [
              ...List.generate(_items.length, (i) => _itemCard(i, _items[i])),

              const SizedBox(height: 4),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Another Item'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: kBlue,
                    side: const BorderSide(color: kBlue, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                      top: BorderSide(color: kBlue, width: 2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kMuted,
                            letterSpacing: 0.5)),
                    Text(
                      'PKR ${_moneyFmt.format(_total)}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: kBlue),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Notes ─────────────────────────────────
          _card(
            title: 'Notes  (optional)',
            child: TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration:
                  const InputDecoration(hintText: 'Any additional notes…'),
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _isEditing ? 'Update Invoice' : 'Save Invoice',
                      style: const TextStyle(fontSize: 16)),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Item card ─────────────────────────────────────────
  Widget _itemCard(int index, _ItemEntry entry) {
    final hasProduct = !entry.isManual && entry.itemName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE2EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
            child: Row(
              children: [
                Text('Item ${index + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kMuted)),
                const Spacer(),
                if (_items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Colors.red),
                    onPressed: () => _removeItem(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                  ),
              ],
            ),
          ),

          // Product Description selector
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Product Description *',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kMuted)),
                const SizedBox(height: 6),

                // Show selected product chip OR manual text field
                if (hasProduct) ...[
                  // Selected product — tap to change
                  GestureDetector(
                    onTap: () => _pickProduct(index),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: kBlueLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kBlue.withOpacity(.4), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: kBlue, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(entry.itemName,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: kBlueDark)),
                          ),
                          const Icon(Icons.swap_horiz,
                              color: kBlue, size: 18),
                        ],
                      ),
                    ),
                  ),
                ] else if (entry.isManual) ...[
                  // Manual text field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: entry.manualCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Type product description…',
                            prefixIcon: Icon(Icons.edit_outlined,
                                size: 18, color: kMuted),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _pickProduct(index),
                        icon: const Icon(Icons.list_alt_outlined,
                            color: kBlue),
                        tooltip: 'Pick from list',
                        style: IconButton.styleFrom(
                          backgroundColor: kBlueLight,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Nothing selected yet — big tap-to-pick button
                  GestureDetector(
                    onTap: () => _pickProduct(index),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFDDE2EA),
                            width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              color: Colors.grey[400], size: 20),
                          const SizedBox(width: 10),
                          Text('Select product…',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400])),
                          const Spacer(),
                          Icon(Icons.keyboard_arrow_down,
                              color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Qty | Price | Amount
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: entry.qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Quantity', hintText: '0'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: entry.priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price / Unit',
                      hintText: '0.00',
                      prefixText: 'PKR ',
                      prefixStyle: TextStyle(color: kMuted, fontSize: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 15),
                    decoration: BoxDecoration(
                      color: entry.amount > 0
                          ? const Color(0xFFEBF7EB)
                          : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: entry.amount > 0
                              ? kGreen.withOpacity(.4)
                              : const Color(0xFFDDE2EA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Amount',
                            style: TextStyle(
                                fontSize: 10,
                                color: kMuted,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          _moneyFmt.format(entry.amount),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: entry.amount > 0
                                  ? kGreenDark
                                  : kMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Widget? trailing,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDDE2EA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: kBlue,
                        letterSpacing: 0.8)),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

// ── Product Picker Bottom Sheet ───────────────────────────
class _ProductPickerSheet extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<String> onProductSelected;
  final VoidCallback onManualSelected;
  final VoidCallback onManageProducts;

  const _ProductPickerSheet({
    required this.products,
    required this.onProductSelected,
    required this.onManualSelected,
    required this.onManageProducts,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 10),
            child: Row(
              children: [
                const Text('Select Product',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onManageProducts,
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Manage', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: kBlue),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Product list
          Expanded(
            child: ListView(
              controller: ctrl,
              children: [
                ...products.map((p) => ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kBlueLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: kBlue, size: 18),
                      ),
                      title: Text(p.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right,
                          color: kMuted, size: 20),
                      onTap: () => onProductSelected(p.name),
                    )),

                const Divider(height: 1, indent: 16, endIndent: 16),

                // Add Manually
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: kGreenDark, size: 18),
                  ),
                  title: const Text('Add Manually',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kGreenDark)),
                  subtitle: const Text('Type a custom description',
                      style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right,
                      color: kMuted, size: 20),
                  onTap: onManualSelected,
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
