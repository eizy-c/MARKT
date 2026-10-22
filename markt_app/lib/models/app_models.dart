class RecipeItem {
  final String id;
  final String? inventoryProductId; // ID del producto en inventario si descuenta stock
  final String name; // e.g. 'Separadores Metálicos', 'Tira LED Neón', 'Corte Láser CNC'
  final String type; // 'material', 'consumible', 'mano_obra', 'corte_cnc', 'instalacion'
  final double quantity; // e.g. 4.0 (unids), 2.5 (metros), 0.5 (horas)
  final String unit; // 'unid', 'mts', 'm2', 'cm2', 'láminas', 'horas', 'global'
  final double unitCostUsd;
  final double unitSalePriceUsd; // Precio de venta unitario asignado al insumo
  final bool deductInventory;
  final double? widthCm;        // Ancho en cm para piezas recortadas (ej: acrílicos, MDF)
  final double? heightCm;       // Alto en cm
  final double? wastePercent;   // Margen de merma / desperdicio (ej: 20%)

  RecipeItem({
    required this.id,
    this.inventoryProductId,
    required this.name,
    this.type = 'material',
    required this.quantity,
    this.unit = 'unid',
    required this.unitCostUsd,
    this.unitSalePriceUsd = 0.0,
    this.deductInventory = true,
    this.widthCm,
    this.heightCm,
    this.wastePercent,
  });

  double get totalCostUsd => quantity * unitCostUsd;
  double get effectiveSalePrice => unitSalePriceUsd > 0 ? unitSalePriceUsd : (unitCostUsd * 1.5);
  double get totalSalePriceUsd => quantity * effectiveSalePrice;

  Map<String, dynamic> toJson() => {
    'id': id,
    'inventoryProductId': inventoryProductId,
    'name': name,
    'type': type,
    'quantity': quantity,
    'unit': unit,
    'unitCostUsd': unitCostUsd,
    'unitSalePriceUsd': unitSalePriceUsd,
    'deductInventory': deductInventory,
    'widthCm': widthCm,
    'heightCm': heightCm,
    'wastePercent': wastePercent,
  };

  factory RecipeItem.fromJson(Map<String, dynamic> json) => RecipeItem(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    inventoryProductId: json['inventoryProductId']?.toString(),
    name: json['name'] ?? '',
    type: json['type'] ?? 'material',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unit: json['unit'] ?? 'unid',
    unitCostUsd: (json['unitCostUsd'] as num?)?.toDouble() ?? 0.0,
    unitSalePriceUsd: (json['unitSalePriceUsd'] as num?)?.toDouble() ?? 0.0,
    deductInventory: json['deductInventory'] ?? true,
    widthCm: (json['widthCm'] as num?)?.toDouble(),
    heightCm: (json['heightCm'] as num?)?.toDouble(),
    wastePercent: (json['wastePercent'] as num?)?.toDouble(),
  );

  RecipeItem copyWith({
    String? id,
    String? inventoryProductId,
    String? name,
    String? type,
    double? quantity,
    String? unit,
    double? unitCostUsd,
    double? unitSalePriceUsd,
    bool? deductInventory,
    double? widthCm,
    double? heightCm,
    double? wastePercent,
  }) {
    return RecipeItem(
      id: id ?? this.id,
      inventoryProductId: inventoryProductId ?? this.inventoryProductId,
      name: name ?? this.name,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCostUsd: unitCostUsd ?? this.unitCostUsd,
      unitSalePriceUsd: unitSalePriceUsd ?? this.unitSalePriceUsd,
      deductInventory: deductInventory ?? this.deductInventory,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      wastePercent: wastePercent ?? this.wastePercent,
    );
  }
}

class ProductCategory {
  final String id;
  final String name;
  final String type; // 'producto', 'servicio', 'material'

  ProductCategory({
    required this.id,
    required this.name,
    this.type = 'producto',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
  };

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? '',
    type: json['type'] ?? 'producto',
  );
}

class Product {
  final String id;
  final String name;
  final String category;
  final String type; // 'producto', 'servicio', 'material'
  final String unit; // 'unid', 'mts', 'm2', 'láminas', etc.
  final double priceUsd;
  final double costUsd;
  final int stock;
  final int minStock;
  final String? code;
  final List<RecipeItem> recipe; // Receta / Consumibles predeterminados
  final String? imagePath; // Foto del producto o trabajo

  Product({
    required this.id,
    required this.name,
    required this.category,
    this.type = 'producto',
    this.unit = 'unid',
    required this.priceUsd,
    this.costUsd = 0.0,
    this.stock = 0,
    this.minStock = 2,
    this.code,
    this.recipe = const [],
    this.imagePath,
  });

  double get recipeTotalSalePriceUsd => recipe.isEmpty ? priceUsd : recipe.fold(0.0, (acc, item) => acc + item.totalSalePriceUsd);

  double get recipeTotalCostUsd {
    if (recipe.isEmpty) return costUsd;
    return recipe.fold(0.0, (acc, item) => acc + item.totalCostUsd);
  }

  double get effectiveCostUsd => recipe.isNotEmpty ? recipeTotalCostUsd : costUsd;

  double get marginPercentage {
    final c = effectiveCostUsd;
    if (priceUsd <= 0) return 0.0;
    if (c <= 0) return 100.0;
    return ((priceUsd - c) / priceUsd) * 100;
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? type,
    String? unit,
    double? priceUsd,
    double? costUsd,
    int? stock,
    int? minStock,
    String? code,
    List<RecipeItem>? recipe,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      priceUsd: priceUsd ?? this.priceUsd,
      costUsd: costUsd ?? this.costUsd,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      code: code ?? this.code,
      recipe: recipe ?? this.recipe,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'type': type,
    'unit': unit,
    'priceUsd': priceUsd,
    'costUsd': costUsd,
    'stock': stock,
    'minStock': minStock,
    'code': code,
    'recipe': recipe.map((r) => r.toJson()).toList(),
    'imagePath': imagePath,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: json['name'] ?? '',
    category: json['category'] ?? 'General',
    type: json['type'] ?? 'producto',
    unit: json['unit'] ?? 'unid',
    priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? (json['price'] as num?)?.toDouble() ?? 0.0,
    costUsd: (json['costUsd'] as num?)?.toDouble() ?? (json['cost'] as num?)?.toDouble() ?? 0.0,
    stock: (json['stock'] as num?)?.toInt() ?? 0,
    minStock: (json['minStock'] as num?)?.toInt() ?? 2,
    code: json['code']?.toString(),
    recipe: (json['recipe'] as List?)?.map((r) => RecipeItem.fromJson(Map<String, dynamic>.from(r))).toList() ?? [],
    imagePath: json['imagePath']?.toString(),
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
  final double commissionPercent;
  final String role; // 'vendedor', 'armador', 'ambos'

  Seller({
    required this.id,
    required this.name,
    required this.code,
    this.commissionPercent = 5.0,
    this.role = 'vendedor',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'commissionPercent': commissionPercent,
    'role': role,
  };

  factory Seller.fromJson(Map<String, dynamic> json) => Seller(
    id: json['id']?.toString() ?? '',
    name: json['name'] ?? '',
    code: json['code'] ?? '',
    commissionPercent: (json['commissionPercent'] as num?)?.toDouble() ?? 5.0,
    role: json['role'] ?? 'vendedor',
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
    this.name = 'Mi Comercio',
    this.rif = '',
    this.phone = '',
    this.address = '',
    this.warrantyNote = 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.',
    this.showQrPagoMovil = true,
    this.showBarcode = true,
    this.showSignatureLine = true,
    this.showIvaBreakdown = false,
    this.ticketTheme = 'pos_termico',
    this.folioCounter = 0,
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
    name: json['name'] ?? 'Mi Comercio',
    rif: json['rif'] ?? '',
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    warrantyNote: json['warrantyNote'] ?? 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.',
    showQrPagoMovil: json['showQrPagoMovil'] ?? true,
    showBarcode: json['showBarcode'] ?? true,
    showSignatureLine: json['showSignatureLine'] ?? true,
    showIvaBreakdown: json['showIvaBreakdown'] ?? false,
    ticketTheme: json['ticketTheme'] ?? 'pos_termico',
    folioCounter: (json['folioCounter'] as num?)?.toInt() ?? 0,
  );
}

class BankAccount {
  final String id;
  final String bankName; // e.g., Banesco, Banco de Venezuela, Mercantil, Provincial
  final String accountNumber;
  final String accountHolder;
  final String docId;
  final String phone; // Para Pago Móvil
  final String accountType; // Corriente, Ahorros, etc.

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.docId,
    required this.phone,
    this.accountType = 'Corriente',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'accountHolder': accountHolder,
    'docId': docId,
    'phone': phone,
    'accountType': accountType,
  };

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    bankName: json['bankName'] ?? '',
    accountNumber: json['accountNumber'] ?? '',
    accountHolder: json['accountHolder'] ?? '',
    docId: json['docId'] ?? '',
    phone: json['phone'] ?? '',
    accountType: json['accountType'] ?? 'Corriente',
  );
}

class Invoice {
  final String id;
  final String folio;
  final String voucherType; // 'factura' | 'cotizacion' | 'egreso' | 'abono'
  final DateTime date;
  final Client client;
  final Seller seller;
  final List<CartItem> items;
  final double rateBcv;
  final String rateCurrency; // 'USD' | 'EUR'
  final String currencyMode; // 'USD' | 'Bs'
  final double totalUsd;
  final double totalBs;
  final String paymentMethod;
  final String? bankName;
  final String? paymentReference;
  final String? notes;
  final BusinessProfile business;

  // Campos avanzados para Cotizaciones y Presupuestos
  final int validityDays; // ej. 3, 5, 7, 15 días
  final double requiredDownPaymentPercent; // ej. 50%
  final double initialPaidUsd; // Monto de anticipo pagado
  final bool hasLighting; // ¿Llevará luces / LED / Neón?
  final double lightingCostUsd;
  final bool hasInstallation; // ¿Llevará instalación en sitio?
  final double installationCostUsd;
  final bool hasDelivery; // ¿Llevará flete / delivery?
  final double deliveryCostUsd;
  final bool hasGraphicDesign; // ¿Llevará diseño gráfico / vectorizado?
  final double graphicDesignCostUsd;
  final String quotationStatus; // 'esperando_inicial', 'en_taller', 'rechazado', 'entregado'

  Invoice({
    required this.id,
    required this.folio,
    this.voucherType = 'factura',
    required this.date,
    required this.client,
    required this.seller,
    required this.items,
    required this.rateBcv,
    this.rateCurrency = 'USD',
    required this.currencyMode,
    required this.totalUsd,
    required this.totalBs,
    required this.paymentMethod,
    this.bankName,
    this.paymentReference,
    this.notes,
    required this.business,
    this.validityDays = 5,
    this.requiredDownPaymentPercent = 50.0,
    this.initialPaidUsd = 0.0,
    this.hasLighting = false,
    this.lightingCostUsd = 0.0,
    this.hasInstallation = false,
    this.installationCostUsd = 0.0,
    this.hasDelivery = false,
    this.deliveryCostUsd = 0.0,
    this.hasGraphicDesign = false,
    this.graphicDesignCostUsd = 0.0,
    this.quotationStatus = 'esperando_inicial',
  });

  // Helpers para Cotizaciones
  DateTime get expirationDate => date.add(Duration(days: validityDays));
  bool get isExpired => DateTime.now().isAfter(expirationDate);
  double get requiredDownPaymentAmountUsd => totalUsd * (requiredDownPaymentPercent / 100);
  double get remainingBalanceUsd => (totalUsd - initialPaidUsd).clamp(0.0, double.infinity);
  bool get isInitialPaid => initialPaidUsd >= (requiredDownPaymentAmountUsd - 0.01);

  double get totalCostUsd => items.fold(0.0, (acc, item) => acc + (item.product.costUsd * item.quantity));
  double get netProfitUsd => totalUsd - totalCostUsd;
  double get sellerCommissionUsd => totalUsd * (seller.commissionPercent / 100);

  Invoice copyWith({
    String? id,
    String? folio,
    String? voucherType,
    DateTime? date,
    Client? client,
    Seller? seller,
    List<CartItem>? items,
    double? rateBcv,
    String? rateCurrency,
    String? currencyMode,
    double? totalUsd,
    double? totalBs,
    String? paymentMethod,
    String? bankName,
    String? paymentReference,
    String? notes,
    BusinessProfile? business,
    int? validityDays,
    double? requiredDownPaymentPercent,
    double? initialPaidUsd,
    bool? hasLighting,
    double? lightingCostUsd,
    bool? hasInstallation,
    double? installationCostUsd,
    bool? hasDelivery,
    double? deliveryCostUsd,
    bool? hasGraphicDesign,
    double? graphicDesignCostUsd,
    String? quotationStatus,
  }) {
    return Invoice(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      voucherType: voucherType ?? this.voucherType,
      date: date ?? this.date,
      client: client ?? this.client,
      seller: seller ?? this.seller,
      items: items ?? this.items,
      rateBcv: rateBcv ?? this.rateBcv,
      rateCurrency: rateCurrency ?? this.rateCurrency,
      currencyMode: currencyMode ?? this.currencyMode,
      totalUsd: totalUsd ?? this.totalUsd,
      totalBs: totalBs ?? this.totalBs,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankName: bankName ?? this.bankName,
      paymentReference: paymentReference ?? this.paymentReference,
      notes: notes ?? this.notes,
      business: business ?? this.business,
      validityDays: validityDays ?? this.validityDays,
      requiredDownPaymentPercent: requiredDownPaymentPercent ?? this.requiredDownPaymentPercent,
      initialPaidUsd: initialPaidUsd ?? this.initialPaidUsd,
      hasLighting: hasLighting ?? this.hasLighting,
      lightingCostUsd: lightingCostUsd ?? this.lightingCostUsd,
      hasInstallation: hasInstallation ?? this.hasInstallation,
      installationCostUsd: installationCostUsd ?? this.installationCostUsd,
      hasDelivery: hasDelivery ?? this.hasDelivery,
      deliveryCostUsd: deliveryCostUsd ?? this.deliveryCostUsd,
      hasGraphicDesign: hasGraphicDesign ?? this.hasGraphicDesign,
      graphicDesignCostUsd: graphicDesignCostUsd ?? this.graphicDesignCostUsd,
      quotationStatus: quotationStatus ?? this.quotationStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'folio': folio,
    'voucherType': voucherType,
    'date': date.toIso8601String(),
    'client': client.toJson(),
    'seller': seller.toJson(),
    'items': items.map((i) => {
      'product': i.product.toJson(),
      'quantity': i.quantity,
    }).toList(),
    'rateBcv': rateBcv,
    'rateCurrency': rateCurrency,
    'currencyMode': currencyMode,
    'totalUsd': totalUsd,
    'totalBs': totalBs,
    'paymentMethod': paymentMethod,
    'bankName': bankName,
    'paymentReference': paymentReference,
    'notes': notes,
    'business': business.toJson(),
    'validityDays': validityDays,
    'requiredDownPaymentPercent': requiredDownPaymentPercent,
    'initialPaidUsd': initialPaidUsd,
    'hasLighting': hasLighting,
    'lightingCostUsd': lightingCostUsd,
    'hasInstallation': hasInstallation,
    'installationCostUsd': installationCostUsd,
    'hasDelivery': hasDelivery,
    'deliveryCostUsd': deliveryCostUsd,
    'hasGraphicDesign': hasGraphicDesign,
    'graphicDesignCostUsd': graphicDesignCostUsd,
    'quotationStatus': quotationStatus,
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id']?.toString() ?? '',
    folio: json['folio'] ?? '',
    voucherType: json['voucherType'] ?? 'factura',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    client: Client.fromJson(Map<String, dynamic>.from(json['client'] ?? {})),
    seller: Seller.fromJson(Map<String, dynamic>.from(json['seller'] ?? {})),
    items: (json['items'] as List?)
            ?.map((i) => CartItem(
                  product: Product.fromJson(Map<String, dynamic>.from(i['product'] ?? {})),
                  quantity: (i['quantity'] as num?)?.toInt() ?? 1,
                ))
            .toList() ??
        [],
    rateBcv: (json['rateBcv'] as num?)?.toDouble() ?? 0.0,
    rateCurrency: json['rateCurrency'] ?? 'USD',
    currencyMode: json['currencyMode'] ?? 'USD',
    totalUsd: (json['totalUsd'] as num?)?.toDouble() ?? 0.0,
    totalBs: (json['totalBs'] as num?)?.toDouble() ?? 0.0,
    paymentMethod: json['paymentMethod'] ?? 'efectivo_usd',
    bankName: json['bankName']?.toString(),
    paymentReference: json['paymentReference']?.toString(),
    notes: json['notes']?.toString(),
    business: BusinessProfile.fromJson(Map<String, dynamic>.from(json['business'] ?? {})),
    validityDays: (json['validityDays'] as num?)?.toInt() ?? 5,
    requiredDownPaymentPercent: (json['requiredDownPaymentPercent'] as num?)?.toDouble() ?? 50.0,
    initialPaidUsd: (json['initialPaidUsd'] as num?)?.toDouble() ?? 0.0,
    hasLighting: json['hasLighting'] == true,
    lightingCostUsd: (json['lightingCostUsd'] as num?)?.toDouble() ?? 0.0,
    hasInstallation: json['hasInstallation'] == true,
    installationCostUsd: (json['installationCostUsd'] as num?)?.toDouble() ?? 0.0,
    hasDelivery: json['hasDelivery'] == true,
    deliveryCostUsd: (json['deliveryCostUsd'] as num?)?.toDouble() ?? 0.0,
    hasGraphicDesign: json['hasGraphicDesign'] == true,
    graphicDesignCostUsd: (json['graphicDesignCostUsd'] as num?)?.toDouble() ?? 0.0,
    quotationStatus: json['quotationStatus']?.toString() ?? 'esperando_inicial',
  );
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
  final String clientPhone;
  final double totalUsd;
  final String status;
  final DateTime date;
  final List<RecipeItem> recipe;
  final String dimensions;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final double assemblyFeeUsd;
  final bool assemblyPaid;
  final DateTime? deliveryDate;
  final List<String> photos;
  final double initialPaidUsd;
  final String? initialPaymentMethod;
  final String? initialPaymentReference;
  final List<ReceivablePayment> payments;

  ProjectItem({
    required this.id,
    required this.title,
    required this.clientName,
    this.clientPhone = '',
    required this.totalUsd,
    required this.status,
    required this.date,
    this.recipe = const [],
    this.dimensions = '',
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.assemblyFeeUsd = 0.0,
    this.assemblyPaid = false,
    this.deliveryDate,
    this.photos = const [],
    this.initialPaidUsd = 0.0,
    this.initialPaymentMethod,
    this.initialPaymentReference,
    this.payments = const [],
  });

  double get totalCostUsd => recipe.fold(0.0, (acc, item) => acc + item.totalCostUsd);
  double get netProfitUsd => totalUsd - totalCostUsd;
  double get profitMarginPercent => totalUsd > 0 ? (netProfitUsd / totalUsd) * 100 : 0.0;

  double get totalPaidUsd => initialPaidUsd + payments.fold(0.0, (acc, p) => acc + p.amountUsd);
  double get balanceDueUsd => (totalUsd - totalPaidUsd).clamp(0.0, double.infinity);
  bool get isFullyPaid => balanceDueUsd <= 0.01;

  bool get isAssemblyReady => (status == '5_finalizado' || status == 'Listo' || status == 'Procesado' || status == 'Entregado');

  double get effectiveAssemblyFeeUsd {
    if (assemblyFeeUsd > 0) return assemblyFeeUsd;
    return recipe.where((it) => it.type == 'mano_obra').fold(0.0, (acc, it) => acc + it.totalCostUsd);
  }

  int? get daysUntilDelivery {
    if (deliveryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deliveryDate!.year, deliveryDate!.month, deliveryDate!.day);
    return target.difference(today).inDays;
  }

  bool get isDeliveryOverdue {
    final d = daysUntilDelivery;
    if (d == null) return false;
    return d < 0 && status != '5_finalizado';
  }

  ProjectItem copyWith({
    String? id,
    String? title,
    String? clientName,
    String? clientPhone,
    double? totalUsd,
    String? status,
    DateTime? date,
    List<RecipeItem>? recipe,
    String? dimensions,
    String? assignedWorkerId,
    String? assignedWorkerName,
    double? assemblyFeeUsd,
    bool? assemblyPaid,
    DateTime? deliveryDate,
    List<String>? photos,
    double? initialPaidUsd,
    String? initialPaymentMethod,
    String? initialPaymentReference,
    List<ReceivablePayment>? payments,
  }) {
    return ProjectItem(
      id: id ?? this.id,
      title: title ?? this.title,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      totalUsd: totalUsd ?? this.totalUsd,
      status: status ?? this.status,
      date: date ?? this.date,
      recipe: recipe ?? this.recipe,
      dimensions: dimensions ?? this.dimensions,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      assemblyFeeUsd: assemblyFeeUsd ?? this.assemblyFeeUsd,
      assemblyPaid: assemblyPaid ?? this.assemblyPaid,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      photos: photos ?? this.photos,
      initialPaidUsd: initialPaidUsd ?? this.initialPaidUsd,
      initialPaymentMethod: initialPaymentMethod ?? this.initialPaymentMethod,
      initialPaymentReference: initialPaymentReference ?? this.initialPaymentReference,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'totalUsd': totalUsd,
    'status': status,
    'date': date.toIso8601String(),
    'recipe': recipe.map((r) => r.toJson()).toList(),
    'dimensions': dimensions,
    'assignedWorkerId': assignedWorkerId,
    'assignedWorkerName': assignedWorkerName,
    'assemblyFeeUsd': assemblyFeeUsd,
    'assemblyPaid': assemblyPaid,
    'deliveryDate': deliveryDate?.toIso8601String(),
    'photos': photos,
    'initialPaidUsd': initialPaidUsd,
    'initialPaymentMethod': initialPaymentMethod,
    'initialPaymentReference': initialPaymentReference,
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory ProjectItem.fromJson(Map<String, dynamic> json) => ProjectItem(
    id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'] ?? '',
    clientName: json['clientName'] ?? '',
    clientPhone: json['clientPhone'] ?? '',
    totalUsd: (json['totalUsd'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] ?? 'pending',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    recipe: (json['recipe'] as List?)?.map((r) => RecipeItem.fromJson(Map<String, dynamic>.from(r))).toList() ?? [],
    dimensions: json['dimensions'] ?? '',
    assignedWorkerId: json['assignedWorkerId']?.toString(),
    assignedWorkerName: json['assignedWorkerName']?.toString(),
    assemblyFeeUsd: (json['assemblyFeeUsd'] as num?)?.toDouble() ?? 0.0,
    assemblyPaid: json['assemblyPaid'] ?? false,
    deliveryDate: json['deliveryDate'] != null ? DateTime.tryParse(json['deliveryDate'].toString()) : null,
    photos: (json['photos'] as List?)?.map((p) => p.toString()).toList() ?? const [],
    initialPaidUsd: (json['initialPaidUsd'] as num?)?.toDouble() ?? 0.0,
    initialPaymentMethod: json['initialPaymentMethod']?.toString(),
    initialPaymentReference: json['initialPaymentReference']?.toString(),
    payments: (json['payments'] as List?)?.map((p) => ReceivablePayment.fromJson(Map<String, dynamic>.from(p))).toList() ?? const [],
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
