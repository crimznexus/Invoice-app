import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../app_theme.dart';
import '../models/invoice.dart';
import '../services/pdf_service.dart';

final _money = NumberFormat('#,##0.00', 'en_PK');
String _fmt(double v) => 'PKR ${_money.format(v)}';

String _fmtDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

class InvoicePreviewScreen extends StatelessWidget {
  final Invoice invoice;
  const InvoicePreviewScreen({super.key, required this.invoice});

  Future<void> _sharePdf(BuildContext context) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Preparing PDF…'),
        ]),
        duration: Duration(seconds: 10),
      ),
    );
    try {
      final bytes = await generateInvoicePdf(invoice);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'Invoice_${invoice.invoiceNumber}.pdf',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final bytes = await generateInvoicePdf(invoice);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text('Invoice #${invoice.invoiceNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => _printPdf(context),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // ── Big share button at bottom ─────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _sharePdf(context),
              icon: const Icon(Icons.share_rounded, size: 22),
              label: const Text(
                'Share Invoice (WhatsApp, Email…)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            // Quick action row
            Row(children: [
              Expanded(
                child: _actionChip(
                  icon: Icons.print_outlined,
                  label: 'Print',
                  color: kBlue,
                  onTap: () => _printPdf(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionChip(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Save PDF',
                  color: const Color(0xFFD32F2F),
                  onTap: () => _sharePdf(context),
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Invoice sheet ────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── Header ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: kSidebar,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset('assets/logo.png',
                              width: 70, height: 70,
                              fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('SALES INVOICE',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 2)),
                              const SizedBox(height: 4),
                              Text('Invoice #${invoice.invoiceNumber}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Meta: Sales Rep | Date | Invoice # ──
                  IntrinsicHeight(
                    child: Row(children: [
                      _metaCell('Sales Rep',
                          invoice.salesRep.isEmpty ? '—' : invoice.salesRep),
                      const VerticalDivider(
                          width: 1, color: Color(0xFFDDE2EA)),
                      _metaCell('Date', _fmtDate(invoice.date)),
                      const VerticalDivider(
                          width: 1, color: Color(0xFFDDE2EA)),
                      _metaCell('Invoice #', invoice.invoiceNumber),
                    ]),
                  ),
                  const Divider(height: 1, color: Color(0xFFDDE2EA)),

                  // ── Bill To ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFF9FAFB),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BILL TO',
                            style: TextStyle(
                                fontSize: 9,
                                color: kMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(invoice.customerName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: kText)),
                        if (invoice.customerAddress.isNotEmpty)
                          Text(invoice.customerAddress,
                              style: const TextStyle(
                                  fontSize: 12, color: kMuted)),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFDDE2EA)),

                  // ── Items ────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 10),
                        decoration: BoxDecoration(
                          color: kBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(children: [
                          SizedBox(
                              width: 36,
                              child: Text('Qty', style: _thStyle)),
                          SizedBox(width: 6),
                          Expanded(
                              child: Text('Product Description',
                                  style: _thStyle)),
                          SizedBox(width: 6),
                          SizedBox(
                              width: 74,
                              child: Text('Price/Unit',
                                  textAlign: TextAlign.right,
                                  style: _thStyle)),
                          SizedBox(width: 6),
                          SizedBox(
                              width: 78,
                              child: Text('Amount',
                                  textAlign: TextAlign.right,
                                  style: _thStyle)),
                        ]),
                      ),
                      const SizedBox(height: 4),

                      // Rows
                      ...invoice.items.asMap().entries.map((e) {
                        final even = e.key.isEven;
                        final item = e.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: even
                                ? Colors.white
                                : const Color(0xFFFAFBFC),
                          ),
                          child: Row(children: [
                            SizedBox(
                                width: 36,
                                child: Text(_qty(item.quantity),
                                    style: _tdStyle)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(item.itemName,
                                    style: _tdStyle)),
                            const SizedBox(width: 6),
                            SizedBox(
                                width: 74,
                                child: Text(_fmt(item.priceEach),
                                    textAlign: TextAlign.right,
                                    style: _tdStyle)),
                            const SizedBox(width: 6),
                            SizedBox(
                                width: 78,
                                child: Text(_fmt(item.amount),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: kGreenDark))),
                          ]),
                        );
                      }),

                      // Total row
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F5FF),
                          border: Border(
                              top: BorderSide(color: kBlue, width: 2)),
                        ),
                        child: Row(children: [
                          const Expanded(
                            child: Text('TOTAL',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kMuted,
                                    letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                              width: 78,
                              child: Text(_fmt(invoice.total),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: kBlue))),
                        ]),
                      ),
                    ]),
                  ),

                  // ── Notes ────────────────────────────
                  if (invoice.notes.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(
                            color: const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('NOTES',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF92400E))),
                          const SizedBox(height: 4),
                          Text(invoice.notes,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF78350F))),
                        ],
                      ),
                    ),

                  // ── Footer ───────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0F2F5),
                      border: Border(
                          top: BorderSide(color: kGreen, width: 2)),
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Row(children: [
                                Text('📍  ',
                                    style: TextStyle(fontSize: 13)),
                                Expanded(
                                  child: Text(
                                    'Moosjan Dairy Feeds, Meerhaji, Shahjamal, Tehsil & District Muzaffargarh',
                                    style: TextStyle(
                                        fontSize: 10, color: kMuted),
                                  ),
                                ),
                              ]),
                              SizedBox(height: 4),
                              Row(children: [
                                Text('📱  ',
                                    style: TextStyle(fontSize: 13)),
                                Text('03013725515',
                                    style: TextStyle(
                                        fontSize: 10, color: kMuted)),
                              ]),
                            ],
                          ),
                        ),
                        const Text('Purity is Everything',
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: kGreenDark,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _metaCell(String label, String value) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: kMuted,
                      letterSpacing: 0.5)),
              const SizedBox(height: 3),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kText)),
            ],
          ),
        ),
      );

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Material(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 7),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
        ),
      );

  static const _thStyle = TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white);
  static const _tdStyle = TextStyle(fontSize: 11, color: kText);

  String _qty(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
}
