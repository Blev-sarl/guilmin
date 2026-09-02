import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/reception_type.dart';
import '../models/operation_line.dart';
import '../models/package_option.dart';
import '../models/stock_operation.dart';
import '../models/user.dart';

class OdooClient {
  String? _cookie;
  final Map<String, ({DateTime time, List<Map<String, dynamic>> data})> _inventoryCache = {};
  String _baseUrl(String url) => url.trim().replaceFirst(RegExp(r'/+$'), '');

  Future<int?> findLocationByBarcode(String url, String barcode) async {
    final result = await _call(url: url, model: 'stock.location', method: 'search_read', kwargs: <String, dynamic>{
      'domain': <Object>[<Object>['barcode', '=', barcode]],
      'fields': <String>['id'],
      'limit': 1,
    }, errorMessage: 'Emplacement introuvable');
    return result.isEmpty ? null : (result.first['id'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> searchLocations(String url, String query) => _call(
    url: url,
    model: 'stock.location',
    method: 'search_read',
    kwargs: <String, dynamic>{
      'domain': query.trim().isEmpty
          ? <Object>[]
          : <Object>['|', <Object>['name', 'ilike', query], <Object>['barcode', 'ilike', query]],
      'fields': <String>['id', 'name', 'barcode'],
      'limit': 20,
      'order': 'complete_name, name',
    },
    errorMessage: 'Impossible de rechercher les emplacements',
  );

  Future<int> createTransfer({required String url, required int pickingTypeId, int? locationId, String origin = ''}) async {
    final result = await _execute(url: url, model: 'stock.picking', method: 'create', args: <Object>[
      <String, dynamic>{
        'picking_type_id': pickingTypeId,
        ...?(locationId == null ? null : <String, dynamic>{'location_id': locationId}),
        if (origin.trim().isNotEmpty) 'origin': origin.trim(),
      },
    ], errorMessage: 'Impossible de créer le transfert');
    if (result is! num) throw Exception('Transfert non créé');
    return result.toInt();
  }

  Future<File> downloadReport({
    required String url,
    required String reportName,
    required List<int> recordIds,
    required String fileName,
    Map<String, dynamic>? data,
  }) async {
    if (recordIds.isEmpty && data == null) {
      throw Exception('Aucune opération à imprimer');
    }
    final reportUri = Uri.parse(
      '${_baseUrl(url)}/report/pdf/$reportName'
      '${recordIds.isEmpty ? '' : '/${recordIds.join(',')}'}',
    );
    debugPrint('Téléchargement rapport Odoo: $reportUri');
    final headers = <String, String>{
      ...?_cookie == null ? null : <String, String>{'Cookie': _cookie!},
    };
    final response = data == null
        ? await http.get(reportUri, headers: headers)
        : await http.post(
            reportUri,
            headers: <String, String>{
              ...headers,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: <String, String>{
              'options': jsonEncode(data),
              'context': jsonEncode(<String, dynamic>{
                if (data['active_model'] != null)
                  'active_model': data['active_model'],
                if (data['active_ids'] != null)
                  'active_ids': data['active_ids'],
              }),
            },
          );
    debugPrint(
      'Réponse rapport Odoo: status=${response.statusCode}, '
      'type=${response.headers['content-type']}, '
      'location=${response.headers['location']}, '
      'cookie=${_cookie != null}',
    );
    final bytes = response.bodyBytes;
    final isPdf = bytes.length >= 4 &&
        bytes[0] == 0x25 && bytes[1] == 0x50 &&
        bytes[2] == 0x44 && bytes[3] == 0x46;
    // Les rapports classiques gardent le comportement historique. La
    // validation stricte est réservée au flux des étiquettes Odoo 19.
    if (response.statusCode != 200 ||
        (data != null && !isPdf) ||
        (data == null && bytes.length < 4)) {
      var message = 'Le rapport d’impression est indisponible';
      if (response.statusCode == 401) {
        message = 'Session Odoo expirée, veuillez vous reconnecter';
      } else if (response.statusCode == 403) {
        message = 'Accès au rapport refusé par Odoo';
      } else if (response.statusCode == 404) {
        message = 'Rapport code-barres introuvable dans Odoo';
      } else if (response.body.toLowerCase().contains('login') ||
          response.body.toLowerCase().contains('<html')) {
        message = 'Odoo a renvoyé une page HTML au lieu du rapport PDF';
      }
      debugPrint(
        'Détail erreur rapport Odoo: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}',
      );
      throw Exception('$message (${response.statusCode})');
    }
    final directory = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return File('${directory.path}/$safeName.pdf')
        .writeAsBytes(bytes, flush: true);
  }

  Future<OdooUser> authenticate({
    required String url,
    required String database,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${_baseUrl(url)}/web/session/authenticate'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, Object>{
        'jsonrpc': '2.0',
        'method': 'call',
        'params': <String, String>{
          'db': database,
          'login': email,
          'password': password,
        },
      }),
    );
    final body = _decodeResponse(response);
    final result = body['result'];
    if (body['error'] != null || result is! Map) {
      throw Exception('Identifiants ou base de données invalides');
    }
    _cookie = response.headers['set-cookie']?.split(';').first;
    return OdooUser.fromJson(Map<String, dynamic>.from(result));
  }

  Future<List<ReceptionType>> getReceptionTypes(String url) async {
    final result = await _call(
      url: url,
      model: 'stock.picking.type',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[],
        'fields': <String>[
          'id',
          'name',
          'sequence_code',
          'warehouse_id',
          'code',
          'count_picking',
        ],
        'order': 'sequence, name',
        'context': <String, String>{'lang': 'fr_BE'},
      },
      errorMessage: 'Impossible de charger les types de réceptions',
    );
    return result.map(ReceptionType.fromJson).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrders(String url) async {
    final result = await _call(
      url: url,
      model: 'purchase.order',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[<Object>['state', '!=', 'cancel']],
        'fields': <String>['id', 'name', 'partner_id', 'partner_ref', 'date_order', 'date_approve', 'state', 'amount_untaxed', 'amount_tax', 'amount_total', 'currency_id', 'picking_type_id'],
        'order': 'date_order desc, id desc',
        'limit': 200,
        'context': <String, String>{'lang': 'fr_BE'},
      },
      errorMessage: 'Impossible de charger les bons de commande',
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderLines(String url, int orderId) {
    return _call(url: url, model: 'purchase.order.line', method: 'search_read', kwargs: <String, dynamic>{
      'domain': <Object>[<Object>['order_id', '=', orderId]],
      'fields': <String>['product_id', 'name', 'product_qty', 'product_uom_id', 'price_unit', 'price_subtotal', 'date_planned'],
      'order': 'id asc',
      'context': <String, String>{'lang': 'fr_BE'},
    }, errorMessage: 'Impossible de charger les lignes du bon de commande');
  }

  Future<List<Map<String, dynamic>>> getPurchaseOrderDeliveries(String url, int orderId) {
    return _call(url: url, model: 'stock.picking', method: 'search_read', kwargs: <String, dynamic>{
      'domain': <Object>[<Object>['purchase_id', '=', orderId]],
      'fields': <String>['id', 'name', 'state', 'scheduled_date', 'date_done', 'location_dest_id', 'picking_type_id'],
      'order': 'scheduled_date asc, id asc',
      'context': <String, String>{'lang': 'fr_BE'},
    }, errorMessage: 'Impossible de charger les livraisons liées');
  }

  Future<List<StockOperation>> getOperations(
    String url,
    int pickingTypeId,
  ) async {
    final result = await _call(
      url: url,
      model: 'stock.picking',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[
          <Object>['picking_type_id', '=', pickingTypeId],
          <Object>[
            'state',
            'not in',
            <String>['cancel'],
          ],
        ],
        'fields': <String>[
          'id',
          'name',
          'purchase_id',
          'origin',
          'partner_id',
          'scheduled_date',
          'state',
        ],
        'order': 'scheduled_date asc, id desc',
      },
      errorMessage: 'Impossible de charger les opérations',
    );
    final purchaseIds = result
        .map((picking) => picking['purchase_id'])
        .whereType<List>()
        .where((relation) => relation.isNotEmpty && relation[0] is num)
        .map((relation) => (relation[0] as num).toInt())
        .toSet()
        .toList();
    if (purchaseIds.isNotEmpty) {
      final purchases = await _call(
        url: url,
        model: 'purchase.order',
        method: 'search_read',
        kwargs: <String, dynamic>{
          'domain': <List<Object>>[
            <Object>['id', 'in', purchaseIds],
          ],
          'fields': <String>['id', 'partner_ref'],
        },
        errorMessage: 'Impossible de charger les références fournisseur',
      );
      final supplierReferences = <int, String>{
        for (final purchase in purchases)
          (purchase['id'] as num).toInt(): purchase['partner_ref'] is String
              ? (purchase['partner_ref'] as String).trim()
              : '',
      };
      for (final picking in result) {
        final purchase = picking['purchase_id'];
        if (purchase is List && purchase.isNotEmpty && purchase[0] is num) {
          picking['partner_ref'] =
              supplierReferences[(purchase[0] as num).toInt()] ?? '';
        }
      }
    }
    if (result.isNotEmpty) {
      final operationIds = result.map((item) => (item['id'] as num).toInt()).toList();
      final moveLines = await _call(
        url: url,
        model: 'stock.move.line',
        method: 'search_read',
        kwargs: <String, dynamic>{
          'domain': <List<Object>>[<Object>['picking_id', 'in', operationIds]],
          'fields': <String>['picking_id', 'package_id', 'result_package_id'],
          'limit': 5000,
        },
        errorMessage: 'Impossible de vérifier les colis des réceptions',
      );
      final packageOperations = <int>{};
      for (final line in moveLines) {
        final picking = line['picking_id'];
        final hasPackage = (line['package_id'] is List && (line['package_id'] as List).isNotEmpty) ||
            (line['result_package_id'] is List && (line['result_package_id'] as List).isNotEmpty);
        if (hasPackage && picking is List && picking.isNotEmpty && picking.first is num) {
          packageOperations.add((picking.first as num).toInt());
        }
      }
      for (final picking in result) {
        picking['_has_packages'] = packageOperations.contains((picking['id'] as num).toInt());
      }
    }
    return result.map(StockOperation.fromJson).toList(growable: false);
  }

  Future<String?> getOperationState(String url, int pickingId) async {
    final result = await _execute(
      url: url,
      model: 'stock.picking',
      method: 'read',
      args: <Object>[<Object>[pickingId]],
      kwargs: <String, dynamic>{'fields': <String>['state']},
      errorMessage: 'Impossible de récupérer l’état du transfert',
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      return (result.first as Map)['state']?.toString();
    }
    return null;
  }

  Future<StockOperation?> getOperation(String url, int pickingId) async {
    final rows = await _call(
      url: url,
      model: 'stock.picking',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[<Object>['id', '=', pickingId]],
        'fields': <String>['id', 'name', 'purchase_id', 'origin', 'partner_id', 'scheduled_date', 'state'],
        'limit': 1,
      },
      errorMessage: 'Impossible de recharger le transfert',
    );
    return rows.isEmpty ? null : StockOperation.fromJson(rows.first);
  }

  Future<List<OperationLine>> getOperationLines(
    String url,
    int operationId,
  ) async {
    final moves = await _call(
      url: url,
      model: 'stock.move',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[
          <Object>['picking_id', '=', operationId],
          <Object>['state', '!=', 'cancel'],
        ],
        'fields': <String>[
          'id',
          'product_id',
          'description_picking',
          'location_dest_id',
          'product_uom_qty',
          'quantity',
          'product_uom',
          'move_line_ids',
        ],
        'order': 'sequence, id',
        'context': <String, String>{'lang': 'fr_BE'},
      },
      errorMessage: 'Impossible de charger les lignes de l’opération',
    );
    final moveLines = await _call(
      url: url,
      model: 'stock.move.line',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[
          <Object>['picking_id', '=', operationId],
          <Object>['state', '!=', 'cancel'],
        ],
        'fields': <String>[
          'id',
          'move_id',
          'quantity',
          'picked',
          'product_uom_id',
          'package_id',
          'result_package_id',
          'result_package_dest_name',
        ],
        'context': <String, String>{'lang': 'fr_BE'},
      },
      errorMessage: 'Impossible de charger le détail des colis',
    );

    final expanded = <Map<String, dynamic>>[];
    for (final move in moves) {
      final moveId = (move['id'] as num).toInt();
      final related = moveLines
          .where((line) {
            final relation = line['move_id'];
            return relation is List &&
                relation.isNotEmpty &&
                relation[0] == moveId;
          })
          .toList(growable: false);
      if (related.isEmpty) {
        move['_move_id'] = moveId;
        move['_move_line_ids'] = <int>[];
        move['_done_quantity'] = 0;
        expanded.add(move);
        continue;
      }
      for (final detail in related) {
        final quantity = (detail['quantity'] as num?)?.toDouble() ?? 0;
        final item = Map<String, dynamic>.from(move);
        item['_line_id'] = detail['id'];
        item['_move_id'] = moveId;
        item['_move_line_ids'] = <dynamic>[detail['id']];
        // Odoo peut renseigner quantity sans positionner picked (notamment
        // après une validation directe d’un brouillon). La quantité réalisée
        // doit donc être lue directement depuis quantity.
        item['_done_quantity'] = quantity;
        // Odoo peut répartir un mouvement en plusieurs lignes (scannée et
        // restante). Chaque ligne doit afficher sa propre quantité.
        item['_unit'] = _relationName(detail['product_uom_id']);
        item['_source_package'] = _relationName(detail['package_id']);
        item['_destination_package'] = _relationName(
          detail['result_package_id'],
        );
        final destinationPackage = detail['result_package_id'];
        item['_destination_package_id'] = destinationPackage is List &&
                destinationPackage.isNotEmpty
            ? destinationPackage[0]
            : null;
        item['_destination_container'] =
            (detail['result_package_dest_name'] ?? '').toString();
        expanded.add(item);
      }
    }
    return expanded.map(OperationLine.fromJson).toList(growable: false);
  }

  String _relationName(dynamic value) =>
      value is List && value.length > 1 ? value[1].toString() : '';

  Future<List<PackageOption>> getPackages(
    String url, {
    String query = '',
  }) async {
    final packages = await _call(
      url: url,
      model: 'stock.package',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': query.isEmpty
            ? <Object>[]
            : <List<Object>>[
                <Object>['name', 'ilike', query],
              ],
        'fields': <String>[
          'id',
          'name',
          'complete_name',
          'location_id',
          'package_dest_id',
          'pack_date',
        ],
        'order': 'name',
        'limit': 100,
      },
      errorMessage: 'Impossible de charger les colis',
    );
    if (packages.isNotEmpty) {
      final packageIds = packages.map((item) => (item['id'] as num).toInt()).toList();
      final quants = await _call(
        url: url,
        model: 'stock.quant',
        method: 'search_read',
        kwargs: <String, dynamic>{
          'domain': <List<Object>>[<Object>['package_id', 'in', packageIds]],
          'fields': <String>['package_id', 'product_id'],
          'limit': 5000,
        },
        errorMessage: 'Impossible de compter les produits des colis',
      );
      final productsByPackage = <int, Set<int>>{};
      for (final quant in quants) {
        final pack = quant['package_id'];
        final product = quant['product_id'];
        if (pack is List && pack.isNotEmpty && pack.first is num && product is List && product.isNotEmpty && product.first is num) {
          productsByPackage.putIfAbsent((pack.first as num).toInt(), () => <int>{}).add((product.first as num).toInt());
        }
      }
      for (final item in packages) {
        item['_product_count'] = productsByPackage[(item['id'] as num).toInt()]?.length ?? 0;
      }
    }
    return packages.map(PackageOption.fromJson).toList(growable: false);
  }

  Future<PackageOption> createPackage(String url, String name) async {
    final result = await _execute(
      url: url,
      model: 'stock.package',
      method: 'create',
      args: <Object>[
        <String, Object>{'name': name.trim()},
      ],
      errorMessage: 'Impossible de créer le colis',
    );
    if (result is! num) throw Exception('Odoo n’a pas retourné le colis créé');
    return PackageOption(
      id: result.toInt(),
      name: name.trim(),
      location: '',
      container: '',
    );
  }

  Future<List<Map<String, dynamic>>> getPackageContents(String url, int packageId) async {
    var contents = await _call(
      url: url,
      model: 'stock.quant',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[<Object>['package_id', '=', packageId]],
        'fields': <String>['product_id', 'quantity', 'reserved_quantity', 'product_uom_id'],
        'order': 'product_id',
      },
      errorMessage: 'Impossible de charger le contenu du colis',
    );
    // Avant la validation, le contenu peut encore être présent uniquement
    // dans les lignes de mouvement et pas encore dans stock.quant.
    if (contents.isEmpty) {
      contents = await _call(
        url: url,
        model: 'stock.move.line',
        method: 'search_read',
        kwargs: <String, dynamic>{
          'domain': <Object>['|',
            <Object>['package_id', '=', packageId],
            <Object>['result_package_id', '=', packageId],
          ],
          'fields': <String>['product_id', 'quantity', 'product_uom_id'],
          'order': 'product_id',
        },
        errorMessage: 'Impossible de charger les lignes du colis',
      );
    }
    final productIds = contents
        .map((item) => item['product_id'])
        .whereType<List>()
        .where((relation) => relation.isNotEmpty && relation.first is num)
        .map((relation) => (relation.first as num).toInt())
        .toSet()
        .toList();
    if (productIds.isNotEmpty) {
      final products = await _call(
        url: url,
        model: 'product.product',
        method: 'search_read',
        kwargs: <String, dynamic>{
          'domain': <List<Object>>[<Object>['id', 'in', productIds]],
          'fields': <String>['id', 'barcode', 'default_code', 'uom_id'],
          'context': <String, String>{'lang': 'fr_BE'},
        },
        errorMessage: 'Impossible de charger les codes-barres des produits',
      );
      final barcodes = <int, String>{
        for (final product in products)
          (product['id'] as num).toInt(): (product['barcode'] ?? '').toString().trim(),
      };
      for (final item in contents) {
        final relation = item['product_id'];
        if (relation is List && relation.isNotEmpty && relation.first is num) {
          final productId = (relation.first as num).toInt();
          item['_barcode'] = barcodes[productId] ?? '';
          final product = products.firstWhere(
            (value) => (value['id'] as num).toInt() == productId,
            orElse: () => <String, dynamic>{},
          );
          item['_uom_name'] = product['uom_id'] is List &&
                  (product['uom_id'] as List).length > 1
              ? product['uom_id'][1].toString()
              : '';
        }
      }
    }
    return contents;
  }

  Future<void> assignPackageToLines(
    String url,
    List<int> lineIds,
    int? packageId, {
    bool source = false,
  }) async {
    if (lineIds.isEmpty) {
      throw Exception('Aucune ligne détaillée disponible pour cet article');
    }
    await _execute(
      url: url,
      model: 'stock.move.line',
      method: 'write',
      args: <Object>[
        lineIds,
        <String, Object?>{
          source ? 'package_id' : 'result_package_id': packageId,
        },
      ],
      errorMessage: 'Impossible d’affecter le colis',
    );
  }

  Future<void> assignPackageToOperation(
    String url,
    int operationId,
    int? packageId,
  ) async {
    final lines = await _call(
      url: url,
      model: 'stock.move.line',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[
          <Object>['picking_id', '=', operationId],
          <Object>['quantity', '>', 0],
        ],
        'fields': <String>['id'],
      },
      errorMessage: 'Impossible de charger les lignes à mettre en colis',
    );
    await assignPackageToLines(
      url,
      lines.map((line) => (line['id'] as num).toInt()).toList(),
      packageId,
    );
  }

  Future<void> setMoveQuantity(
    String url,
    int moveId,
    List<int> moveLineIds,
    double quantity,
  ) async {
    if (moveLineIds.isNotEmpty) {
      await _execute(
        url: url,
        model: 'stock.move.line',
        method: 'write',
        args: <Object>[
          <int>[moveLineIds.first],
          quantity == 0
              ? <String, Object>{'picked': false}
              : <String, Object>{'quantity': quantity, 'picked': true},
        ],
        errorMessage: 'Impossible d’enregistrer la quantité traitée',
      );
      return;
    }
    await _execute(
      url: url,
      model: 'stock.move',
      method: 'write',
      args: <Object>[
        <int>[moveId],
        <String, Object>{'quantity': quantity, 'picked': quantity > 0},
      ],
      errorMessage: 'Impossible d’enregistrer la quantité',
    );
  }

  Future<void> incrementMoveDemand(String url, int moveId, double quantity) async {
    await _execute(
      url: url,
      model: 'stock.move',
      method: 'write',
      args: <Object>[<int>[moveId], <String, Object>{'product_uom_qty': quantity + 1}],
      errorMessage: 'Impossible d’incrémenter la quantité demandée',
    );
  }

  Future<void> setMoveDemand(String url, int moveId, double quantity) => _execute(url: url, model: 'stock.move', method: 'write', args: <Object>[<int>[moveId], <String, Object>{'product_uom_qty': quantity}], errorMessage: 'Impossible de modifier la quantité demandée');

  Future<void> deleteDraftMove(String url, int moveId) => _execute(url: url, model: 'stock.move', method: 'unlink', args: <Object>[<int>[moveId]], errorMessage: 'Impossible de supprimer le produit du brouillon');

  Future<int?> findProductByBarcode(String url, String barcode) async {
    final result = await _call(
      url: url,
      model: 'product.product',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[
          '|',
          <Object>['barcode', '=', barcode],
          <Object>['default_code', '=ilike', barcode],
        ],
        'fields': <String>['id'],
        'limit': 1,
      },
      errorMessage: 'Impossible de rechercher le code-barres',
    );
    return result.isEmpty ? null : (result.first['id'] as num).toInt();
  }

  Future<List<Map<String, dynamic>>> getInventoryProducts(String url, {String query = ''}) async {
    final key = '$url|${query.trim().toLowerCase()}';
    final cached = _inventoryCache[key];
    if (cached != null && DateTime.now().difference(cached.time) < const Duration(seconds: 10)) return cached.data;
    final data = await _call(url: url, model: 'product.product', method: 'search_read', kwargs: <String, dynamic>{'domain': query.trim().isEmpty ? <Object>[] : <Object>['|', '|', <Object>['name', 'ilike', query], <Object>['default_code', 'ilike', query], <Object>['barcode', 'ilike', query]], 'fields': <String>['id', 'name', 'default_code', 'barcode', 'list_price', 'qty_available', 'uom_id'], 'limit': 500, 'order': 'name', 'context': <String, String>{'lang': 'fr_BE'}}, errorMessage: 'Impossible de charger l’inventaire');
    _inventoryCache[key] = (time: DateTime.now(), data: data);
    return data;
  }
  Future<Map<String,dynamic>> getProductDetails(String url,int id) async { final r=await _call(url:url,model:'product.product',method:'search_read',kwargs:<String,dynamic>{'domain':<Object>[<Object>['id','=',id]],'fields':<String>['name','default_code','barcode','list_price','standard_price','qty_available','uom_id','type','sale_ok','purchase_ok'],'limit':1,'context':<String,String>{'lang':'fr_BE'}},errorMessage:'Impossible de charger le produit'); if(r.isEmpty) throw Exception('Produit introuvable'); return r.first; }
  Future<List<Map<String,dynamic>>> getProductLocations(String url, int productId) => _call(url:url, model:'stock.quant', method:'search_read', kwargs:<String,dynamic>{'domain':<Object>[<Object>['product_id','=',productId],<Object>['quantity','>',0],<Object>['location_id.usage','=','internal']], 'fields':<String>['location_id','quantity','reserved_quantity','product_uom_id'], 'order':'location_id'}, errorMessage:'Impossible de charger les emplacements');

  Future<void> addProductToDraftTransfer({required String url, required int pickingId, required int productId, required double quantity}) async {
    final p = await _call(url: url, model: 'stock.picking', method: 'search_read', kwargs: <String, dynamic>{'domain': <Object>[<Object>['id', '=', pickingId]], 'fields': <String>['location_id', 'location_dest_id', 'picking_type_id']}, errorMessage: 'Impossible de charger le transfert');
    final product = await _call(url: url, model: 'product.product', method: 'search_read', kwargs: <String, dynamic>{'domain': <Object>[<Object>['id', '=', productId]], 'fields': <String>['name', 'uom_id']}, errorMessage: 'Impossible de charger le produit');
    if (p.isEmpty || product.isEmpty) throw Exception('Transfert ou produit introuvable');
    final src = p.first['location_id']; final dest = p.first['location_dest_id']; final uom = product.first['uom_id'];
    if (src is! List || dest is! List || uom is! List) throw Exception('Emplacements invalides');
    final createdMove = await _execute(url: url, model: 'stock.move', method: 'create', args: <Object>[
      <String, dynamic>{
        'picking_id': pickingId,
        'picking_type_id': (p.first['picking_type_id'] as List).first,
        'product_id': productId,
        'product_uom_qty': quantity,
        'product_uom': uom.first,
        'location_id': src.first,
        'location_dest_id': dest.first,
        'procure_method': 'make_to_stock',
      },
    ], errorMessage: 'Impossible d’ajouter le produit au transfert');
    if (createdMove is! num) throw Exception('Odoo n’a pas confirmé l’ajout du produit');
  }

  Future<List<Map<String, dynamic>>> getKitComponents(
    String url,
    int productId,
  ) async {
    final products = await _call(
      url: url,
      model: 'product.product',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[
          <Object>['id', '=', productId],
        ],
        'fields': <String>['product_tmpl_id'],
        'limit': 1,
      },
      errorMessage: 'Impossible de charger le produit',
    );
    final template = products.isNotEmpty ? products.first['product_tmpl_id'] : null;
    final templateId = template is List && template.isNotEmpty
        ? (template[0] as num).toInt()
        : null;
    final boms = await _call(
      url: url,
      model: 'mrp.bom',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[
          '|',
          <Object>['product_id', '=', productId],
          <Object>['product_tmpl_id', '=', templateId ?? 0],
          <Object>['type', '=', 'phantom'],
        ],
        'fields': <String>['id'],
        'limit': 1,
      },
      errorMessage: 'Impossible de rechercher le kit',
    );
    if (boms.isEmpty) return <Map<String, dynamic>>[];
    return _call(
      url: url,
      model: 'mrp.bom.line',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <List<Object>>[
          <Object>['bom_id', '=', (boms.first['id'] as num).toInt()],
        ],
        'fields': <String>['product_id', 'product_qty', 'product_uom_id'],
        'order': 'sequence, id',
      },
      errorMessage: 'Impossible de charger les composants du kit',
    );
  }

  Future<Map<int, List<String>>> getProductScanCodes(
    String url,
    Iterable<int> productIds,
  ) async {
    final ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) return <int, List<String>>{};
    final result = await _call(
      url: url,
      model: 'product.product',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[
          <Object>['id', 'in', ids],
        ],
        'fields': <String>['id', 'barcode', 'default_code'],
      },
      errorMessage: 'Impossible de charger les codes produits',
    );
    final codes = <int, List<String>>{};
    for (final product in result) {
      final id = (product['id'] as num).toInt();
      codes[id] = <String>[
        if (product['barcode'] is String &&
            (product['barcode'] as String).trim().isNotEmpty)
          (product['barcode'] as String).trim(),
        if (product['default_code'] is String &&
            (product['default_code'] as String).trim().isNotEmpty)
          (product['default_code'] as String).trim(),
      ];
    }
    return codes;
  }

  Future<List<int>> getProductTemplateIds(
    String url,
    Iterable<int> productIds,
  ) async {
    final ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) return <int>[];
    final products = await _call(
      url: url,
      model: 'product.product',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[
          <Object>['id', 'in', ids],
        ],
        'fields': <String>['product_tmpl_id'],
      },
      errorMessage: 'Impossible de charger les produits',
    );
    return products
        .map((product) => product['product_tmpl_id'])
        .where((relation) => relation is List && relation.isNotEmpty)
        .map((relation) => (relation[0] as num).toInt())
        .toSet()
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> prepareProductLabelReport({
    required String url,
    required List<int> productIds,
    required String layout,
  }) async {
    if (productIds.isEmpty) {
      throw Exception('Aucun produit à imprimer');
    }
    final wizardId = await _execute(
      url: url,
      model: 'product.label.layout',
      method: 'create',
      args: <Object>[
        <String, Object>{
          'product_ids': <Object>[<Object>[6, 0, productIds]],
          'move_quantity': 'move',
          'print_format': layout,
        },
      ],
      kwargs: <String, dynamic>{
        'context': <String, Object>{
          'active_model': 'product.product',
          'active_ids': productIds,
          'active_id': productIds.first,
        },
      },
      errorMessage: 'Impossible de préparer les étiquettes Odoo',
    );
    if (wizardId is! num) {
      throw Exception('Assistant d’étiquettes Odoo invalide');
    }
    final action = await _execute(
      url: url,
      model: 'product.label.layout',
      method: 'process',
      args: <Object>[<int>[wizardId.toInt()]],
      kwargs: <String, dynamic>{
        'context': <String, Object>{
          'active_model': 'product.product',
          'active_ids': productIds,
          'active_id': productIds.first,
        },
      },
      errorMessage: 'Impossible de générer les étiquettes Odoo',
    );
    if (action is! Map) {
      throw Exception('Odoo n’a pas retourné de rapport d’étiquettes');
    }
    return Map<String, dynamic>.from(action);
  }

  Future<List<Map<String, dynamic>>> getPackageReports(String url) async {
    return _call(
      url: url,
      model: 'ir.actions.report',
      method: 'search_read',
      kwargs: <String, dynamic>{
        'domain': <Object>[
          <Object>['model', '=', 'stock.package'],
          <Object>['report_type', 'in', <String>['qweb-pdf', 'qweb-text']],
        ],
        'fields': <String>['name', 'report_name', 'report_type', 'paperformat_id'],
        'order': 'name',
        'context': <String, String>{'lang': 'fr_BE'},
      },
      errorMessage: 'Impossible de charger les rapports de colis',
    );
  }

  Future<void> putInPack(String url, int operationId) async {
    await _execute(
      url: url,
      model: 'stock.picking',
      method: 'action_put_in_pack',
      args: <Object>[
        <int>[operationId],
      ],
      errorMessage: 'Impossible de mettre les produits en colis',
    );
  }

  Future<dynamic> validateOperation(String url, int operationId) {
    return _execute(
      url: url,
      model: 'stock.picking',
      method: 'button_validate',
      args: <Object>[
        <int>[operationId],
      ],
      errorMessage: 'Impossible de valider l’opération',
    );
  }

  Future<void> markTransferToDo(String url, int operationId) async {
    await _execute(
      url: url,
      model: 'stock.picking',
      method: 'action_confirm',
      args: <Object>[<int>[operationId]],
      errorMessage: 'Impossible de marquer le transfert à faire',
    );
    await _execute(
      url: url,
      model: 'stock.picking',
      method: 'action_assign',
      args: <Object>[<int>[operationId]],
      errorMessage: 'Impossible de réserver le transfert',
    );
    final lines = await _call(url: url, model: 'stock.move.line', method: 'search_read', kwargs: <String, dynamic>{
      'domain': <Object>[<Object>['picking_id', '=', operationId]],
      'fields': <String>['id'],
    }, errorMessage: 'Impossible de préparer les lignes du transfert');
    final ids = lines.map((line) => (line['id'] as num).toInt()).toList();
    if (ids.isNotEmpty) {
      await _execute(url: url, model: 'stock.move.line', method: 'write', args: <Object>[
        ids,
        <String, Object>{'quantity': 0, 'picked': false},
      ], errorMessage: 'Impossible de remettre la quantité traitée à zéro');
    }
  }

  Future<void> processValidationAction(
    String url,
    Map<dynamic, dynamic> action, {
    bool createBackorder = true,
  }) async {
    final model = action['res_model']?.toString();
    final recordId = action['res_id'];
    if (model == null || recordId is! num) {
      throw Exception('Confirmation Odoo non prise en charge');
    }
    final method = model == 'stock.backorder.confirmation' && !createBackorder
        ? 'process_cancel_backorder'
        : 'process';
    await _execute(
      url: url,
      model: model,
      method: method,
      args: <Object>[
        <int>[recordId.toInt()],
      ],
      kwargs: action['context'] is Map
          ? <String, dynamic>{
              'context': Map<String, dynamic>.from(action['context'] as Map),
            }
          : const <String, dynamic>{},
      errorMessage: 'Impossible de confirmer la validation',
    );
  }

  Future<List<Map<String, dynamic>>> _call({
    required String url,
    required String model,
    required String method,
    required Map<String, dynamic> kwargs,
    required String errorMessage,
  }) async {
    final result = await _execute(
      url: url,
      model: model,
      method: method,
      kwargs: kwargs,
      errorMessage: errorMessage,
    );
    if (result is! List) {
      throw Exception(errorMessage);
    }
    return result
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<dynamic> _execute({
    required String url,
    required String model,
    required String method,
    List<Object> args = const <Object>[],
    Map<String, dynamic> kwargs = const <String, dynamic>{},
    required String errorMessage,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_cookie != null) {
      headers['Cookie'] = _cookie!;
    }
    final response = await http.post(
      Uri.parse('${_baseUrl(url)}/web/dataset/call_kw/$model/$method'),
      headers: headers,
      body: jsonEncode(<String, Object>{
        'jsonrpc': '2.0',
        'method': 'call',
        'params': <String, Object>{
          'model': model,
          'method': method,
          'args': args,
          'kwargs': kwargs,
        },
      }),
    );
    final body = _decodeResponse(response);
    if (body['error'] != null) {
      final error = body['error'];
      final data = error is Map ? error['data'] : null;
      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : errorMessage;
      throw Exception(message);
    }
    return body['result'];
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Serveur Odoo inaccessible (${response.statusCode})');
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } on FormatException {
      throw Exception('Réponse invalide du serveur Odoo');
    }
  }
}
