class Product {
  final String id;
  final String name;
  final String category;
  final double priceUsd;
  final int stock;
  final String? code;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.priceUsd,
    this.stock = 0,
    this.code,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'priceUsd': priceUsd,
    'stock': stock,
    'code': code,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? '',
    category: json['category'] ?? 'General',
    priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    code: json['code']?.toString(),
  );
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalUsd => product.priceUsd * quantity;
}

class CashMovement {
  final String id;
  final String type; // 'income' | 'expense'
  final String category;
  final double amountUsd;
  final double amountBs;
  final String method; // 'efectivo_usd', 'pago_movil', etc.
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

class Client {
  final String id;
  final String name;
  final String docId;
  final String phone;
  final String address;

  Client({
    required this.id,
    required this.name,
    required this.docId,
    required this.phone,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'docId': docId,
    'phone': phone,
    'address': address,
  };

  factory Client.fromJson(Map<String, dynamic> json) => Client(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? '',
    docId: json['docId'] ?? json['rif'] ?? '',
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
  );
}

class ProjectItem {
  final String id;
  final String title;
  final String clientName;
  final double totalUsd;
  final String status; // 'pending', 'in_progress', 'completed'
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
