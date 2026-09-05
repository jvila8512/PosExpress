import 'dart:math';
import 'package:drift/drift.dart';
import 'package:etecsa/core/database/app_database.dart';
import 'package:uuid/uuid.dart';

class TestDataGenerator {
  static final _uuid = const Uuid();
  static final _random = Random();

  static final _products = [
    // === Básicos (8) ===
    {'name': 'Arroz (kg)', 'cat': 'Básicos', 'price': 60.0, 'cost': 45.0},
    {'name': 'Azúcar (kg)', 'cat': 'Básicos', 'price': 70.0, 'cost': 55.0},
    {'name': 'Café (lb)', 'cat': 'Básicos', 'price': 120.0, 'cost': 90.0},
    {'name': 'Aceite (l)', 'cat': 'Básicos', 'price': 90.0, 'cost': 70.0},
    {'name': 'Sal (kg)', 'cat': 'Básicos', 'price': 25.0, 'cost': 15.0},
    {'name': 'Fideos (kg)', 'cat': 'Básicos', 'price': 45.0, 'cost': 30.0},
    {'name': 'Lentejas (kg)', 'cat': 'Básicos', 'price': 80.0, 'cost': 60.0},
    {'name': 'Harina (kg)', 'cat': 'Básicos', 'price': 35.0, 'cost': 22.0},

    // === Bebidas (8) ===
    {'name': 'Refresco Cola 350ml', 'cat': 'Bebidas', 'price': 60.0, 'cost': 40.0},
    {'name': 'Refresco Naranja 350ml', 'cat': 'Bebidas', 'price': 60.0, 'cost': 40.0},
    {'name': 'Agua Mineral 1.5L', 'cat': 'Bebidas', 'price': 40.0, 'cost': 25.0},
    {'name': 'Cerveza Nacional', 'cat': 'Bebidas', 'price': 30.0, 'cost': 20.0},
    {'name': 'Cerveza Importada', 'cat': 'Bebidas', 'price': 150.0, 'cost': 110.0},
    {'name': 'Malta', 'cat': 'Bebidas', 'price': 25.0, 'cost': 15.0},
    {'name': 'Ron Añejo 750ml', 'cat': 'Bebidas', 'price': 350.0, 'cost': 280.0},
    {'name': 'Vino Tinto 750ml', 'cat': 'Bebidas', 'price': 250.0, 'cost': 190.0},

    // === Limpieza (6) ===
    {'name': 'Jabón en Barra', 'cat': 'Limpieza', 'price': 25.0, 'cost': 15.0},
    {'name': 'Detergente (kg)', 'cat': 'Limpieza', 'price': 55.0, 'cost': 40.0},
    {'name': 'Cloro 1L', 'cat': 'Limpieza', 'price': 35.0, 'cost': 22.0},
    {'name': 'Esponja (3 uds)', 'cat': 'Limpieza', 'price': 20.0, 'cost': 12.0},
    {'name': 'Suavizante 500ml', 'cat': 'Limpieza', 'price': 45.0, 'cost': 30.0},
    {'name': 'Limpiapisos 1L', 'cat': 'Limpieza', 'price': 40.0, 'cost': 25.0},

    // === Higiene (6) ===
    {'name': 'Papel Higiénico (4 rollos)', 'cat': 'Higiene', 'price': 80.0, 'cost': 60.0},
    {'name': 'Pasta de Dientes', 'cat': 'Higiene', 'price': 45.0, 'cost': 30.0},
    {'name': 'Shampoo', 'cat': 'Higiene', 'price': 65.0, 'cost': 45.0},
    {'name': 'Desodorante', 'cat': 'Higiene', 'price': 55.0, 'cost': 38.0},
    {'name': 'Jabón Líquido', 'cat': 'Higiene', 'price': 50.0, 'cost': 35.0},
    {'name': 'Algodón (pct)', 'cat': 'Higiene', 'price': 30.0, 'cost': 18.0},

    // === Panadería (5) ===
    {'name': 'Pan (unidad)', 'cat': 'Panadería', 'price': 15.0, 'cost': 8.0},
    {'name': 'Galletas (paquete)', 'cat': 'Panadería', 'price': 30.0, 'cost': 18.0},
    {'name': 'Tostadas (paquete)', 'cat': 'Panadería', 'price': 35.0, 'cost': 22.0},
    {'name': 'Pastelito (unidad)', 'cat': 'Panadería', 'price': 10.0, 'cost': 5.0},
    {'name': 'Torta (porción)', 'cat': 'Panadería', 'price': 40.0, 'cost': 25.0},

    // === Lácteos (5) ===
    {'name': 'Leche (l)', 'cat': 'Lácteos', 'price': 50.0, 'cost': 38.0},
    {'name': 'Queso (lb)', 'cat': 'Lácteos', 'price': 120.0, 'cost': 95.0},
    {'name': 'Huevos (docena)', 'cat': 'Lácteos', 'price': 100.0, 'cost': 80.0},
    {'name': 'Mantequilla (barra)', 'cat': 'Lácteos', 'price': 40.0, 'cost': 28.0},
    {'name': 'Yogur (unidad)', 'cat': 'Lácteos', 'price': 25.0, 'cost': 16.0},

    // === Carnes y Embutidos (6) ===
    {'name': 'Pollo (kg)', 'cat': 'Carnes', 'price': 180.0, 'cost': 140.0},
    {'name': 'Carne de Res (kg)', 'cat': 'Carnes', 'price': 250.0, 'cost': 200.0},
    {'name': 'Cerdo (kg)', 'cat': 'Carnes', 'price': 160.0, 'cost': 120.0},
    {'name': 'Salchicha (paq)', 'cat': 'Carnes', 'price': 90.0, 'cost': 65.0},
    {'name': 'Jamón (lb)', 'cat': 'Carnes', 'price': 110.0, 'cost': 80.0},
    {'name': 'Tocineta (lb)', 'cat': 'Carnes', 'price': 130.0, 'cost': 95.0},

    // === Conservas y Enlatados (6) ===
    {'name': 'Atún (lata)', 'cat': 'Conservas', 'price': 80.0, 'cost': 60.0},
    {'name': 'Frijoles Negros (lata)', 'cat': 'Conservas', 'price': 40.0, 'cost': 25.0},
    {'name': 'Chicharos (lata)', 'cat': 'Conservas', 'price': 35.0, 'cost': 20.0},
    {'name': 'Salsa de Tomate', 'cat': 'Conservas', 'price': 30.0, 'cost': 18.0},
    {'name': 'Mayonesa', 'cat': 'Conservas', 'price': 55.0, 'cost': 38.0},
    {'name': 'Mostaza', 'cat': 'Conservas', 'price': 40.0, 'cost': 25.0},
  ];

  static final _expenseData = {
    'Alquiler': ['Alquiler local mensual', 'Alquiler local'],
    'Servicios': ['Electricidad', 'Agua', 'Teléfono'],
    'Transporte': ['Gasolina moto', 'Flete mercancía'],
    'Varios': ['Sacar basura', 'Reparación local'],
  };

  static String _randomBank() {
    const banks = ['ETECSA', 'BPA', 'BANDIC'];
    return banks[_random.nextInt(banks.length)];
  }

  static String _randomPhone() {
    final n = 100 + _random.nextInt(900);
    final m = 1000 + _random.nextInt(9000);
    return '+535$n$m';
  }

  static String _pickRandom(List<String> list) => list[_random.nextInt(list.length)];

  static Future<Map<String, dynamic>> generate(AppDatabase db, String adminId) async {
    int totalSales = 0;
    int totalExpenses = 0;
    int totalDespachos = 0;

    // 1. Categorías
    final categories = <String, String>{};

    // Cargar categorías existentes para evitar duplicados
    final existingCats = await db.select(db.categories).get();
    for (final cat in existingCats) {
      categories[cat.name] = cat.id;
    }

    for (final p in _products) {
      final catName = p['cat'] as String;
      if (!categories.containsKey(catName)) {
        final catId = _uuid.v4();
        await db.into(db.categories).insert(
          CategoriesCompanion.insert(id: catId, name: catName),
          mode: InsertMode.insertOrIgnore,
        );
        categories[catName] = catId;
      }
    }

    // 2. Productos
    final productIds = <String>[];
    final productPrices = <String, double>{};
    final productCosts = <String, double>{};
    final productNames = <String, String>{};

    // Cargar productos existentes para evitar duplicados
    final existingProducts = await db.select(db.products).get();
    final existingProductNames = existingProducts.map((p) => p.name).toSet();
    for (final p in existingProducts) {
      productIds.add(p.id);
      productPrices[p.id] = p.unitPrice;
      productCosts[p.id] = p.costPrice;
      productNames[p.id] = p.name;
    }

    for (final p in _products) {
      final name = p['name'] as String;
      if (existingProductNames.contains(name)) continue; // Ya existe, skip

      final id = _uuid.v4();
      final catId = categories[p['cat']]!;
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: id,
          name: name,
          unitPrice: p['price'] as double,
          categoryId: Value(catId),
          costPrice: Value(p['cost'] as double),
        ),
      );
      productIds.add(id);
      productPrices[id] = p['price'] as double;
      productCosts[id] = p['cost'] as double;
      productNames[id] = name;
    }

    // 3. Lotes iniciales (mayo 2026, antes de junio)
    for (final pid in productIds) {
      await db.addInventoryLot(
        productId: pid,
        quantity: 200,
        costPerUnit: productCosts[pid]!,
        purchaseDate: DateTime(2026, 5, 15).add(Duration(days: _random.nextInt(15))),
      );
    }

    // 4. Vendedoras (skip si ya existen)
    final vendedoras = <Map<String, String>>[];
    final existingUsers = await db.select(db.users).get();
    final existingUsernames = existingUsers.map((u) => u.username).toSet();

    for (final vName in ['María', 'Claudia']) {
      final username = vName.toLowerCase();
      if (existingUsernames.contains(username)) {
        // Ya existe — buscar su ID
        final existing = existingUsers.firstWhere((u) => u.username == username);
        vendedoras.add({'id': existing.id, 'name': vName});
        continue;
      }
      final vId = _uuid.v4();
      await db.createUser(
        id: vId,
        username: username,
        fullName: vName,
        password: '123456',
        role: 'vendedor',
      );
      vendedoras.add({'id': vId, 'name': vName});
    }

    // 5. Junio 2026 completo (día 1 al 23)
    final startDate = DateTime(2026, 6, 1);
    final endDate = DateTime(2026, 6, 23);

    for (int dayOffset = 0; dayOffset < 23; dayOffset++) {
      final currentDate = startDate.add(Duration(days: dayOffset));
      if (currentDate.weekday == 7) continue; // Skip domingos

      final sessionDate = DateTime(currentDate.year, currentDate.month, currentDate.day, 8, 0);
      final sessionId = _uuid.v4();

      double sessionTotalSales = 0;
      double sessionTotalCash = 0;
      double sessionTotalTransfer = 0;

      // 8-15 ventas por día
      final numSales = 8 + _random.nextInt(8);
      for (int s = 0; s < numSales; s++) {
        final saleTime = sessionDate.add(Duration(hours: 1 + _random.nextInt(10), minutes: _random.nextInt(60)));
        final numItems = 1 + _random.nextInt(4);
        double orderTotal = 0;

        final orderId = _uuid.v4();
        final saleId = 'S$orderId'; // ID para la tabla sales
        final mainPaymentMethod = _random.nextDouble() < 0.6
            ? 'efectivo'
            : (_random.nextDouble() < 0.9 ? 'transferencia' : 'mixto');

        // Crear registro en sales (para dashboard y reportes)
        // Se insertará después de calcular el total

        await db.into(db.orders).insert(
          OrdersCompanion.insert(
            id: orderId,
            sessionId: sessionId,
            sellerId: adminId,
            subtotal: 0,
            totalAmount: 0,
          ),
        );

        // Items temporales para calcular total antes de crear sale
        final tempItems = <Map<String, dynamic>>[];

        for (int i = 0; i < numItems && i < productIds.length; i++) {
          final pid = productIds[_random.nextInt(productIds.length)];
          final qty = double.parse((1.0 + _random.nextDouble() * 3).toStringAsFixed(1));
          final price = productPrices[pid]!;
          final cost = productCosts[pid]!;
          final subtotal = qty * price;
          orderTotal += subtotal;

          tempItems.add({
            'index': i,
            'pid': pid,
            'qty': qty,
            'price': price,
            'cost': cost,
            'subtotal': subtotal,
          });

          await db.into(db.orderItems).insert(
            OrderItemsCompanion.insert(
              id: _uuid.v4(),
              orderId: orderId,
              productId: pid,
              productName: productNames[pid]!,
              quantity: qty,
              unitPrice: price,
              subtotal: subtotal,
              costPrice: Value(cost),
            ),
          );
        }

        // Actualizar total de la orden
        await (db.update(db.orders)..where((o) => o.id.equals(orderId))).write(
          OrdersCompanion(
            subtotal: Value(orderTotal),
            totalAmount: Value(orderTotal),
            status: const Value('paid'),
            createdAt: Value(saleTime),
            paidAt: Value(saleTime),
          ),
        );

        // Crear registro en sales (para dashboard y reportes)
        await db.createSale(
          id: saleId,
          sellerId: adminId,
          totalAmount: orderTotal,
          paymentMethod: mainPaymentMethod,
          sessionId: sessionId,
          saleDate: saleTime,
        );

        // Crear saleItems
        for (final item in tempItems) {
          await db.addSaleItem(
            id: '${saleId}_${item['index']}',
            saleId: saleId,
            productId: item['pid'] as String,
            quantity: item['qty'] as double,
            unitPrice: item['price'] as double,
            costPriceAtSale: item['cost'] as double,
            subtotal: item['subtotal'] as double,
          );
        }

        // Pago
        final payRoll = _random.nextDouble();
        if (payRoll < 0.6) {
          await db.into(db.orderPayments).insert(
            OrderPaymentsCompanion.insert(
              id: _uuid.v4(),
              orderId: orderId,
              paymentMethod: 'efectivo',
              amount: orderTotal,
            ),
          );
          sessionTotalCash += orderTotal;
        } else if (payRoll < 0.9) {
          await db.into(db.orderPayments).insert(
            OrderPaymentsCompanion.insert(
              id: _uuid.v4(),
              orderId: orderId,
              paymentMethod: 'transferencia',
              amount: orderTotal,
              transactionId: Value('TX${100000 + _random.nextInt(900000)}'),
              clientName: Value('Cliente ${_random.nextInt(200)}'),
              clientPhone: Value(_randomPhone()),
              bank: Value(_randomBank()),
            ),
          );
          sessionTotalTransfer += orderTotal;
        } else {
          final half = orderTotal / 2;
          await db.into(db.orderPayments).insert(
            OrderPaymentsCompanion.insert(
              id: _uuid.v4(),
              orderId: orderId,
              paymentMethod: 'efectivo',
              amount: half,
            ),
          );
          await db.into(db.orderPayments).insert(
            OrderPaymentsCompanion.insert(
              id: _uuid.v4(),
              orderId: orderId,
              paymentMethod: 'transferencia',
              amount: half,
              transactionId: Value('TX${100000 + _random.nextInt(900000)}'),
              clientName: Value('Cliente ${_random.nextInt(200)}'),
              clientPhone: Value(_randomPhone()),
              bank: Value(_randomBank()),
            ),
          );
          sessionTotalCash += half;
          sessionTotalTransfer += half;
        }

        sessionTotalSales += orderTotal;
        totalSales++;
      }

      // Cerrar sesión de caja
      await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          id: sessionId,
          userId: adminId,
          openingTime: sessionDate,
          openingCash: 500 + _random.nextDouble() * 500,
          totalSales: Value(sessionTotalSales),
          totalCash: Value(sessionTotalCash),
          totalTransfer: Value(sessionTotalTransfer),
          totalProfit: Value(sessionTotalSales * 0.25 + _random.nextDouble() * 500),
          status: const Value('closed'),
          closingTime: Value(sessionDate.add(const Duration(hours: 10))),
          closingCash: Value(500 + sessionTotalCash + _random.nextDouble() * 20),
        ),
      );

      // Gastos
      if (currentDate.day == 1) {
        await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            id: _uuid.v4(),
            category: 'Alquiler',
            description: 'Alquiler local mensual',
            amount: 3000,
            paymentMethod: const Value('transferencia'),
            registeredBy: Value(adminId),
            expenseDate: Value(currentDate),
          ),
        );
        totalExpenses++;
      }

      if (_random.nextDouble() < 0.6) {
        final cat = _pickRandom(_expenseData.keys.toList());
        final desc = _pickRandom(_expenseData[cat]!);
        final amount = cat == 'Alquiler' ? 3000.0 : (50 + _random.nextDouble() * 300);

        await db.into(db.expenses).insert(
          ExpensesCompanion.insert(
            id: _uuid.v4(),
            category: cat,
            description: desc,
            amount: amount,
            paymentMethod: Value(_random.nextDouble() < 0.5 ? 'efectivo' : 'transferencia'),
            registeredBy: Value(adminId),
            expenseDate: Value(DateTime(currentDate.year, currentDate.month, currentDate.day, 14 + _random.nextInt(4))),
          ),
        );
        totalExpenses++;
      }

      // Despachos martes y jueves
      if (currentDate.weekday == 2 || currentDate.weekday == 4) {
        for (final v in vendedoras) {
          final despachoId = _uuid.v4();
          final numDespachoItems = 3 + _random.nextInt(4);
          final usedIdx = <int>{};
          final despachoProductos = <Map<String, dynamic>>[];

          for (int i = 0; i < numDespachoItems; i++) {
            int idx;
            do { idx = _random.nextInt(productIds.length); } while (usedIdx.contains(idx));
            usedIdx.add(idx);
            final pid = productIds[idx];
            final qty = double.parse((10 + _random.nextDouble() * 20).toStringAsFixed(1));
            despachoProductos.add({
              'productId': pid,
              'productName': productNames[pid],
              'quantity': qty,
              'costPrice': productCosts[pid],
              'salePrice': productPrices[pid],
            });
          }

          await db.into(db.despachosEnviados).insert(
            DespachosEnviadosCompanion.insert(
              id: despachoId,
              vendedoraId: v['id']!,
              vendedoraNombre: v['name']!,
              fechaEnvio: Value(currentDate),
              productosCount: Value(despachoProductos.length),
              rawJson: despachoProductos.toString(),
            ),
          );

          await db.into(db.despachosRecibidos).insert(
            DespachosRecibidosCompanion.insert(
              id: _uuid.v4(),
              vendedoraId: v['id']!,
              vendedoraNombre: v['name']!,
              fechaDespacho: currentDate,
              productosCount: Value(despachoProductos.length),
              rawJson: despachoProductos.toString(),
            ),
          );

          for (final item in despachoProductos) {
            await db.addInventoryLot(
              productId: item['productId'] as String,
              quantity: item['quantity'] as double,
              costPerUnit: item['costPrice'] as double,
              purchaseDate: currentDate,
            );
          }

          totalDespachos++;

          // Rendición día siguiente
          final rendicionDate = currentDate.add(const Duration(days: 1));
          if (rendicionDate.isBefore(endDate.add(const Duration(days: 1)))) {
            final numRVentas = 3 + _random.nextInt(5);
            double rTotal = 0, rEfectivo = 0, rTransfer = 0;
            int rItems = 0;
            final rVentas = <Map<String, dynamic>>[];

            for (int r = 0; r < numRVentas; r++) {
              final usedR = <int>{};
              final numItemsR = 1 + _random.nextInt(3);
              double ventaTotal = 0;
              final items = <Map<String, dynamic>>[];

              for (int ri = 0; ri < numItemsR; ri++) {
                int idx;
                do { idx = _random.nextInt(despachoProductos.length); } while (usedR.contains(idx));
                usedR.add(idx);
                final item = despachoProductos[idx];
                final qty = double.parse((1 + _random.nextDouble() * 2).toStringAsFixed(1));
                final subtotal = qty * (item['salePrice'] as double);
                ventaTotal += subtotal;
                rItems++;
                items.add({
                  'productId': item['productId'],
                  'productName': item['productName'],
                  'quantity': qty,
                  'unitPrice': item['salePrice'],
                  'subtotal': subtotal,
                });
              }

              final isTransfer = _random.nextDouble() < 0.4;
              if (isTransfer) { rTransfer += ventaTotal; } else { rEfectivo += ventaTotal; }
              rTotal += ventaTotal;
              rVentas.add({'total': ventaTotal, 'items': items});
            }

            await db.into(db.rendicionesProcesadas).insert(
              RendicionesProcesadasCompanion.insert(
                id: _uuid.v4(),
                vendedoraId: v['id']!,
                vendedoraNombre: v['name']!,
                fechaRendicion: rendicionDate,
                totalEfectivo: Value(rEfectivo),
                totalTransferencia: Value(rTransfer),
                totalGeneral: Value(rTotal),
                totalItems: Value(rItems),
                rawJson: rVentas.toString(),
              ),
            );

            final rSessionId = _uuid.v4();
            await db.into(db.sessions).insert(
              SessionsCompanion.insert(
                id: rSessionId,
                userId: v['id']!,
                openingTime: DateTime(rendicionDate.year, rendicionDate.month, rendicionDate.day, 8),
                openingCash: 0,
                totalSales: Value(rTotal),
                totalCash: Value(rEfectivo),
                totalTransfer: Value(rTransfer),
                totalProfit: Value(rTotal * 0.20),
                status: const Value('closed'),
                closingTime: Value(DateTime(rendicionDate.year, rendicionDate.month, rendicionDate.day, 18)),
                closingCash: Value(rEfectivo),
              ),
            );

            for (final venta in rVentas) {
              final ventaOrderId = _uuid.v4();
              final ventaSaleId = 'SV$ventaOrderId';
              final ventaItems = venta['items'] as List<dynamic>;
              final rPayMethod = _random.nextDouble() < 0.4 ? 'transferencia' : 'efectivo';

              await db.into(db.orders).insert(
                OrdersCompanion.insert(
                  id: ventaOrderId,
                  sessionId: rSessionId,
                  sellerId: v['id']!,
                  subtotal: 0,
                  totalAmount: 0,
                ),
              );

              double orderTotal = 0;
              int itemIdx = 0;
              for (final item in ventaItems) {
                final itemMap = item as Map<String, dynamic>;
                final pid = itemMap['productId'] as String;
                orderTotal += itemMap['subtotal'] as double;
                await db.into(db.orderItems).insert(
                  OrderItemsCompanion.insert(
                    id: _uuid.v4(),
                    orderId: ventaOrderId,
                    productId: pid,
                    productName: itemMap['productName'] as String,
                    quantity: itemMap['quantity'] as double,
                    unitPrice: itemMap['unitPrice'] as double,
                    subtotal: itemMap['subtotal'] as double,
                    costPrice: Value(productCosts[pid] ?? 0),
                  ),
                );
                itemIdx++;
              }

              await (db.update(db.orders)..where((o) => o.id.equals(ventaOrderId))).write(
                OrdersCompanion(
                  subtotal: Value(orderTotal),
                  totalAmount: Value(orderTotal),
                  status: const Value('paid'),
                ),
              );

              // Crear registro en sales para rendiciones
              await db.createSale(
                id: ventaSaleId,
                sellerId: v['id']!,
                totalAmount: orderTotal,
                paymentMethod: rPayMethod,
                sessionId: rSessionId,
                saleDate: DateTime(rendicionDate.year, rendicionDate.month, rendicionDate.day, 9 + _random.nextInt(8)),
              );

              // Crear saleItems
              int si = 0;
              for (final item in ventaItems) {
                final itemMap = item as Map<String, dynamic>;
                final pid = itemMap['productId'] as String;
                await db.addSaleItem(
                  id: '${ventaSaleId}_$si',
                  saleId: ventaSaleId,
                  productId: pid,
                  quantity: itemMap['quantity'] as double,
                  unitPrice: itemMap['unitPrice'] as double,
                  costPriceAtSale: productCosts[pid] ?? 0,
                  subtotal: itemMap['subtotal'] as double,
                );
                si++;
              }
            }
          }
        }
      }
    }

    return {
      'products': productIds.length,
      'categories': categories.length,
      'vendedoras': vendedoras.length,
      'sales': totalSales,
      'expenses': totalExpenses,
      'despachos': totalDespachos,
      'days': 23,
    };
  }
}
