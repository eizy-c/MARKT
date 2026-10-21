import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'debug_logger.dart';
import 'storage_service.dart';

class BcvRates {
  final double usd;
  final double eur;
  final DateTime lastUpdated;
  final bool isLive;

  BcvRates({
    required this.usd,
    required this.eur,
    required this.lastUpdated,
    this.isLive = false,
  });

  Map<String, dynamic> toJson() => {
    'usd': usd,
    'eur': eur,
    'lastUpdated': lastUpdated.toIso8601String(),
    'isLive': isLive,
  };

  factory BcvRates.fromJson(Map<String, dynamic> json) => BcvRates(
    usd: (json['usd'] as num?)?.toDouble() ?? 881.88,
    eur: (json['eur'] as num?)?.toDouble() ?? 988.97,
    lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ?? DateTime.now(),
    isLive: json['isLive'] == true,
  );
}

class BcvService {
  static final BcvService instance = BcvService._internal();
  BcvService._internal();

  final ValueNotifier<BcvRates> ratesNotifier = ValueNotifier<BcvRates>(
    BcvRates(
      usd: 881.88,
      eur: 988.97,
      lastUpdated: DateTime.now(),
      isLive: false,
    ),
  );

  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  BcvRates get currentRates => ratesNotifier.value;

  Future<void> init() async {
    // 1. Cargar caché previo
    try {
      final cached = await StorageService.instance.load('bcv_rates');
      if (cached != null && cached is Map<String, dynamic>) {
        ratesNotifier.value = BcvRates.fromJson(cached);
      }
    } catch (_) {}

    // 2. Consultar en vivo al entrar a la app
    fetchRates();
  }

  Future<bool> fetchRates() async {
    isLoading.value = true;
    DebugLogger.instance.info('Consultando tasa oficial BCV del día...');

    double? fetchedUsd;
    double? fetchedEur;
    DateTime updateDate = DateTime.now();

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    // Intento 1: DolarApi cotizaciones generales
    try {
      final request = await client.getUrl(Uri.parse('https://ve.dolarapi.com/v1/cotizaciones'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List;
        for (final item in list) {
          if (item['moneda'] == 'USD' && item['fuente'] == 'oficial') {
            fetchedUsd = (item['promedio'] as num?)?.toDouble();
          }
          if (item['moneda'] == 'EUR' && item['fuente'] == 'oficial') {
            fetchedEur = (item['promedio'] as num?)?.toDouble();
          }
        }
      }
    } catch (e1) {
      DebugLogger.instance.warn('Fallo endpoint 1 DolarApi cotizaciones: $e1');
    }

    // Intento 2: DolarApi oficial individual si falta USD
    if (fetchedUsd == null) {
      try {
        final request = await client.getUrl(Uri.parse('https://ve.dolarapi.com/v1/dolares/oficial'));
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body);
          fetchedUsd = (data['promedio'] as num?)?.toDouble();
        }
      } catch (e2) {
        DebugLogger.instance.warn('Fallo endpoint 2 DolarApi oficial: $e2');
      }
    }

    client.close();

    final usd = (fetchedUsd != null && fetchedUsd > 0) ? fetchedUsd : ratesNotifier.value.usd;
    final eur = (fetchedEur != null && fetchedEur > 0) ? fetchedEur : ratesNotifier.value.eur;
    final isLive = fetchedUsd != null;

    final updated = BcvRates(
      usd: usd,
      eur: eur,
      lastUpdated: updateDate,
      isLive: isLive,
    );

    ratesNotifier.value = updated;
    isLoading.value = false;

    // Guardar tasa en almacenamiento persistente
    await StorageService.instance.save('bcv_rates', updated.toJson());

    if (isLive) {
      DebugLogger.instance.info('Tasa BCV del día actualizada con éxito: 1 USD = ${usd.toStringAsFixed(2)} Bs.');
    } else {
      DebugLogger.instance.warn('No se pudo conectar a la API BCV. Usando tasa almacenada: ${usd.toStringAsFixed(2)} Bs.');
    }

    return isLive;
  }
}
