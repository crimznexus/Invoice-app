import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/invoice.dart';

final _money = NumberFormat('#,##0.00', 'en_PK');

String _fmt(double v) => 'PKR ${_money.format(v)}';

String _fmtDate(String iso) {
  try {
    return DateFormat('dd MMM yyyy').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

const _blue  = PdfColor.fromInt(0xFF0057B8);
const _green = PdfColor.fromInt(0xFF4DB848);
const _grey  = PdfColor.fromInt(0xFFF5F5F5);
const _borderC = PdfColor.fromInt(0xFFCCCCCC);

Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
  final doc = pw.Document();

  // Load assets
  final logoBytes     = await rootBundle.load('assets/logo.png');
  final locationBytes = await rootBundle.load('assets/icon_location.png');
  final phoneBytes    = await rootBundle.load('assets/icon_phone.png');

  final logoImage     = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final locationIcon  = pw.MemoryImage(locationBytes.buffer.asUint8List());
  final phoneIcon     = pw.MemoryImage(phoneBytes.buffer.asUint8List());

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── HEADER ──────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Image(logoImage, width: 110),
              pw.Spacer(),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'SALES INVOICE',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: _blue,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Invoice #${invoice.invoiceNumber}',
                    style: const pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),

          pw.Divider(color: _blue, thickness: 2),
          pw.SizedBox(height: 8),

          // ── META: Sales Rep | Date | Invoice # ──────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _borderC),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                _metaCell('Sales Rep', invoice.salesRep.isEmpty ? '—' : invoice.salesRep),
                _metaDivider(),
                _metaCell('Date', _fmtDate(invoice.date)),
                _metaDivider(),
                _metaCell('Invoice #', invoice.invoiceNumber),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // ── BILL TO ──────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF9FAFB),
              border: pw.Border.all(color: _borderC),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('BILL TO',
                    style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                        letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Text(invoice.customerName,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (invoice.customerAddress.isNotEmpty)
                  pw.Text(invoice.customerAddress,
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey700)),
              ],
            ),
          ),

          pw.SizedBox(height: 10),

          // ── ITEMS TABLE ──────────────────────────────
          pw.Table(
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: _borderC),
              horizontalInside: pw.BorderSide(color: _borderC, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(42),
              1: pw.FixedColumnWidth(36),
              2: pw.FlexColumnWidth(),
              3: pw.FixedColumnWidth(75),
              4: pw.FixedColumnWidth(85),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _blue),
                children: [
                  _th('Bags', align: pw.TextAlign.center),
                  _th('Qty'),
                  _th('Product Description'),
                  _th('Price / Unit', align: pw.TextAlign.right),
                  _th('Amount', align: pw.TextAlign.right),
                ],
              ),
              // Data rows
              ...invoice.items.asMap().entries.map((e) {
                final even = e.key.isEven;
                final item = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: even ? PdfColors.white : const PdfColor.fromInt(0xFFFAFBFC),
                  ),
                  children: [
                    _td(item.noOfBags > 0 ? item.noOfBags.toString() : '—',
                        align: pw.TextAlign.center),
                    _td(_qty(item.quantity)),
                    _td(item.itemName),
                    _td(_fmt(item.priceEach), align: pw.TextAlign.right),
                    _td(_fmt(item.amount), align: pw.TextAlign.right),
                  ],
                );
              }),
              // Total row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF0F5FF),
                ),
                children: [
                  _td(''),
                  _td(''),
                  _td(''),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: pw.Text('Total',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    child: pw.Text(_fmt(invoice.total),
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: _blue)),
                  ),
                ],
              ),
            ],
          ),

          // ── NOTES ────────────────────────────────────
          if (invoice.notes.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFFBEB),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFFDE68A)),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('NOTES',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                  pw.SizedBox(height: 3),
                  pw.Text(invoice.notes,
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],

          pw.Spacer(),

          // ── FOOTER ───────────────────────────────────
          pw.Divider(color: _green, thickness: 2),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(locationIcon, width: 12, height: 12),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        'Moosjan Dairy Feeds, Meerhaji, Shahjamal, Tehsil & District Muzaffargarh',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Image(phoneIcon, width: 12, height: 12),
                      pw.SizedBox(width: 5),
                      pw.Text('03013725515',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.Text('Purity is Everything',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontStyle: pw.FontStyle.italic,
                      color: _green)),
            ],
          ),
        ],
      ),
    ),
  );

  return doc.save();
}

// ── Helper widgets ────────────────────────────────────────

pw.Widget _metaCell(String label, String value) => pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(),
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.grey600, letterSpacing: 0.5)),
            pw.SizedBox(height: 3),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );

pw.Widget _metaDivider() => pw.Container(
      width: 1,
      height: 46,
      color: _borderC,
    );

pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      child: pw.Text(text,
          textAlign: align,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );

pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(text,
          textAlign: align,
          style: const pw.TextStyle(fontSize: 10)),
    );

String _qty(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
