import 'dart:convert';

class InvoiceItem {
  final String itemName;
  final String description;
  final double quantity;
  final double priceEach;
  final double amount;
  final int noOfBags;

  InvoiceItem({
    this.itemName = '',
    required this.description,
    required this.quantity,
    required this.priceEach,
    required this.amount,
    this.noOfBags = 0,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        itemName: j['itemName'] ?? '',
        description: j['description'] ?? '',
        quantity: (j['quantity'] as num).toDouble(),
        priceEach: (j['priceEach'] as num).toDouble(),
        amount: (j['amount'] as num).toDouble(),
        noOfBags: (j['noOfBags'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'description': description,
        'quantity': quantity,
        'priceEach': priceEach,
        'amount': amount,
        'noOfBags': noOfBags,
      };

  InvoiceItem copyWith({
    String? itemName,
    String? description,
    double? quantity,
    double? priceEach,
    double? amount,
    int? noOfBags,
  }) =>
      InvoiceItem(
        itemName: itemName ?? this.itemName,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        priceEach: priceEach ?? this.priceEach,
        amount: amount ?? this.amount,
        noOfBags: noOfBags ?? this.noOfBags,
      );
}

class Invoice {
  final int? id;
  final String invoiceNumber;
  final String date;
  final String salesRep;
  final String customerName;
  final String customerAddress;
  final List<InvoiceItem> items;
  final double total;
  final String notes;
  final String createdAt;

  const Invoice({
    this.id,
    required this.invoiceNumber,
    required this.date,
    this.salesRep = '',
    required this.customerName,
    this.customerAddress = '',
    required this.items,
    required this.total,
    this.notes = '',
    required this.createdAt,
  });

  factory Invoice.fromMap(Map<String, dynamic> m) {
    final itemsList = (jsonDecode(m['items_json'] as String) as List)
        .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return Invoice(
      id: m['id'] as int?,
      invoiceNumber: m['invoice_number'] as String,
      date: m['date'] as String,
      salesRep: m['sales_rep'] as String? ?? '',
      customerName: m['customer_name'] as String,
      customerAddress: m['customer_address'] as String? ?? '',
      items: itemsList,
      total: (m['total'] as num).toDouble(),
      notes: m['notes'] as String? ?? '',
      createdAt: m['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_number': invoiceNumber,
        'date': date,
        'sales_rep': salesRep,
        'customer_name': customerName,
        'customer_address': customerAddress,
        'items_json': jsonEncode(items.map((e) => e.toJson()).toList()),
        'total': total,
        'notes': notes,
        'created_at': createdAt,
      };

  Invoice copyWith({
    int? id,
    String? invoiceNumber,
    String? date,
    String? salesRep,
    String? customerName,
    String? customerAddress,
    List<InvoiceItem>? items,
    double? total,
    String? notes,
    String? createdAt,
  }) =>
      Invoice(
        id: id ?? this.id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        date: date ?? this.date,
        salesRep: salesRep ?? this.salesRep,
        customerName: customerName ?? this.customerName,
        customerAddress: customerAddress ?? this.customerAddress,
        items: items ?? this.items,
        total: total ?? this.total,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}
