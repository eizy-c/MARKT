class Product {
  final String id;
  final String name;
  final String category;
  final double priceUsd;
  final double costUsd;
  final int stock;
  final int minStock;
  final String? code;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.priceUsd,
    this.costUsd = 0.0,
    this.stock = 0,
    this.minStock = 2,
    this.code,
  });

  double get marginPercentage {
    if (priceUsd <= 0) return 0.0;
    if (costUsd <= 0) return 100.0;
    return ((priceUsd - costUsd) / priceUsd) * 100;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'priceUsd': priceUsd,
    'costUsd': costUsd,
    'stock': stock,
    'minStock': minStock,
    'code': code,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? '',
    category: json['category'] ?? 'General',
    priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
    costUsd: (json['costUsd'] as num?)?.toDouble() ?? (json['cost'] as num?)?.toDouble() ?? 0.0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    minStock: (json['minStock'] as num?)?.toInt() ?? 2,
    code: json['code']?.toString(),
  );
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalUsd => product.priceUsd * quantity;
}

class Client {
  final String id;
  final String docId; // CI / RIF / DNI
  final String firstName;
  final String lastName;
  final String phone; // WhatsApp número
  final String address;

  Client({
    required this.id,
    required this.docId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address,
  });

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'docId': docId,
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'address': address,
  };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    docId: json['docId'] ?? json['rif'] ?? json['ci'] ?? '',
    firstName: json['firstName'] ?? json['name'] ?? '',
    lastName: json['lastName'] ?? '',
    phone: json['phone'] ?? json['whatsapp'] ?? '',
    address: json['address'] ?? '',
  );
}

class Seller {
  final String id;
  final String name;
  final String code;

  Seller({required this.id, required this.name, required this.code});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
  };

  factory Seller.fromJson(Map<String, dynamic> json) => Seller(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? '',
    code: json['code'] ?? '',
  );
}

class BusinessProfile {
  String name;
  String rif;
  String phone;
  String address;
  String warrantyNote;
  bool showQrPagoMovil;
  bool showBarcode;
  bool showSignatureLine;
  bool showIvaBreakdown;
  String ticketTheme; // 'pos_termico', 'indigo_moderno', 'esmeralda_eco'
  int folioCounter;

  BusinessProfile({
    this.name = 'EIZY STORE',
    this.rif = 'V-28425010',
    this.phone = '0414-5803945',
    this.address = 'Lara - Barquisimeto',
    this.warrantyNote = 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.',
    this.showQrPagoMovil = true,
    this.showBarcode = true,
    this.showSignatureLine = true,
    this.showIvaBreakdown = false,
    this.ticketTheme = 'pos_termico',
    this.folioCounter = 90,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'rif': rif,
    'phone': phone,
    'address': address,
    'warrantyNote': warrantyNote,
    'showQrPagoMovil': showQrPagoMovil,
    'showBarcode': showBarcode,
    'showSignatureLine': showSignatureLine,
    'showIvaBreakdown': showIvaBreakdown,
    'ticketTheme': ticketTheme,
    'folioCounter': folioCounter,
  };

  factory BusinessProfile.fromJson(Map<String, dynamic> json) => BusinessProfile(
    name: json['name'] ?? 'EIZY STORE',
    rif: json['rif'] ?? 'V-28425010',
    phone: json['phone'] ?? '0414-5803945',
    address: json['address'] ?? 'Lara - Barquisimeto',
    warrantyNote: json['warrantyNote'] ?? 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.',
    showQrPagoMovil: json['showQrPagoMovil'] ?? true,
    showBarcode: json['showBarcode'] ?? true,
    showSignatureLine: json['showSignatureLine'] ?? true,
    showIvaBreakdown: json['showIvaBreakdown'] ?? false,
    ticketTheme: json['ticketTheme'] ?? 'pos_termico',
    folioCounter: (json['folioCounter'] as num?)?.toInt() ?? 90,
  );
}

class Invoice {
  final String id;
  final String folio;
  final DateTime date;
  final Client client;
  final Seller seller;
  final List<CartItem> items;
  final double rateBcv;
  final String currencyMode; // 'USD' | 'Bs'
  final double totalUsd;
  final double totalBs;
  final String paymentMethod;
  final BusinessProfile business;

  Invoice({
    required this.id,
    required this.folio,
    required this.date,
    required this.client,
    required this.seller,
    required this.items,
    required this.rateBcv,
    required this.currencyMode,
    required this.totalUsd,
    required this.totalBs,
    required this.paymentMethod,
    required this.business,
  });
}

class CashMovement {
  final String id;
  final String type;
  final String category;
  final double amountUsd;
  final double amountBs;
  final String method;
  final String description;
  final DateTime date;

  CashMovement({
    required this.id,
    required this.type,
    required this.category,
    required this.amountUsd,
    required this.amountBs,
    required this.method,
    required this.description,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'category': category,
    'amountUsd': amountUsd,
    'amountBs': amountBs,
    'method': method,
    'description': description,
    'date': date.toIso8601String(),
  };

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    type: json['type'] ?? 'income',
    category: json['category'] ?? 'General',
    amountUsd: (json['amountUsd'] as num?)?.toDouble() ?? 0.0,
    amountBs: (json['amountBs'] as num?)?.toDouble() ?? 0.0,
    method: json['method'] ?? 'efectivo_usd',
    description: json['description'] ?? '',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
  );
}

class ProjectItem {
  final String id;
  final String title;
  final String clientName;
  final double totalUsd;
  final String status;
  final DateTime date;

  ProjectItem({
    required this.id,
    required this.title,
    required this.clientName,
    required this.totalUsd,
    required this.status,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'clientName': clientName,
    'totalUsd': totalUsd,
    'status': status,
    'date': date.toIso8601String(),
  };

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] ?? '',
    clientName: json['clientName'] ?? '',
    totalUsd: (json['totalUsd'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] ?? 'pending',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
  );
}

class ReceivablePayment {
  final String id;
  final double amountUsd;
  final String method;
  final DateTime date;
  final String note;

  ReceivablePayment({
    required this.id,
    required this.amountUsd,
    required this.method,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amountUsd': amountUsd,
    'method': method,
    'date': date.toIso8601String(),
    'note': note,
  };

  factory ReceivablePayment.fromJson(Map<String, dynamic> json) => ReceivablePayment(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    amountUsd: (json['amountUsd'] as num?)?.toDouble() ?? 0.0,
    method: json['method'] ?? 'pago_movil',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    note: json['note'] ?? '',
  );
}

class ReceivableAccount {
  final String id;
  final String clientName;
  final String clientPhone;
  final String concept;
  final double totalUsd;
  final List<ReceivablePayment> payments;
  final DateTime dueDate;
  final DateTime createdAt;

  ReceivableAccount({
    required this.id,
    required this.clientName,
    required this.clientPhone,
    required this.concept,
    required this.totalUsd,
    this.payments = const [],
    required this.dueDate,
    required this.createdAt,
  });

  double get totalPaidUsd => payments.fold(0.0, (acc, p) => acc + p.amountUsd);
  double get remainingBalanceUsd => (totalUsd - totalPaidUsd).clamp(0.0, double.infinity);
  bool get isPaid => remainingBalanceUsd <= 0.01;
  bool get isOverdue => !isPaid && DateTime.now().isAfter(dueDate);

  String get status {
    if (isPaid) return 'saldada';
    if (isOverdue) return 'vencida';
    return 'al_dia';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'concept': concept,
    'totalUsd': totalUsd,
    'payments': payments.map((p) => p.toJson()).toList(),
    'dueDate': dueDate.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReceivableAccount.fromJson(Map<String, dynamic> json) => ReceivableAccount(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    clientName: json['clientName'] ?? '',
    clientPhone: json['clientPhone'] ?? '',
    concept: json['concept'] ?? 'Venta a crédito',
    totalUsd: (json['totalUsd'] as num?)?.toDouble() ?? 0.0,
    payments: (json['payments'] as List?)
            ?.map((p) => ReceivablePayment.fromJson(Map<String, dynamic>.from(p)))
            .toList() ??
        [],
    dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 15)),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
