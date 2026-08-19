import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reception_type.dart';
import '../models/operation_line.dart';
import '../models/package_option.dart';
import '../models/stock_operation.dart';
import '../models/user.dart';

class OdooClient {
  String? _cookie;
  String _baseUrl(String url) => url.trim().replaceFirst(RegExp(r'/+$'), '');

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
      },
      errorMessage: 'Impossible de charger les types de réceptions',
    );
    return result.map(ReceptionType.fromJson).toList(growable: false);
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
            <String>['done', 'cancel'],
          ],
        ],
        'fields': <String>[
          'id',
          'name',
          'origin',
          'partner_id',
          'scheduled_date',
          'state',
        ],
        'order': 'scheduled_date asc, id desc',
      },
      errorMessage: 'Impossible de charger les opérations',
    );
    return result.map(StockOperation.fromJson).toList(growable: false);
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
        item['_done_quantity'] = detail['picked'] == true ? quantity : 0;
        item['product_uom_qty'] = quantity;
        item['_unit'] = _relationName(detail['product_uom_id']);
        item['_source_package'] = _relationName(detail['package_id']);
        item['_destination_package'] = _relationName(
          detail['result_package_id'],
        );
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
        ],
        'order': 'name',
        'limit': 100,
      },
      errorMessage: 'Impossible de charger les colis',
    );
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
