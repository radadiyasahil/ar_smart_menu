import 'package:dio/dio.dart';

import '../../models/product_model.dart';
import 'api_client.dart';

class UploadPhotoResult {
  const UploadPhotoResult({
    required this.photo,
    required this.autoSubmitted,
    this.product,
    this.message,
  });

  final ProductPhotoModel photo;
  final bool autoSubmitted;
  final ProductModel? product;
  final String? message;
}

class ProductService {
  ProductService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<ProductModel>> list() async {
    final response = await _dio.get<Map<String, dynamic>>('/products');
    return _parseList(response.data!);
  }

  Future<ProductModel> getById(String id) async {
    final response = await _dio.get<Map<String, dynamic>>('/products/$id');
    return _parseOne(response.data!);
  }

  Future<ProductModel> create({
    required String name,
    String? description,
    int? pricePaise,
    ProductCategory? category,
    VegStatus vegStatus = VegStatus.notApplicable,
    bool isSpicy = false,
    bool isBestseller = false,
    bool isNew = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/products',
      data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        if (pricePaise != null) 'pricePaise': pricePaise,
        if (category != null) 'category': category.value,
        'vegStatus': vegStatus.value,
        'isSpicy': isSpicy,
        'isBestseller': isBestseller,
        'isNew': isNew,
      },
    );
    return _parseOne(response.data!);
  }

  Future<ProductModel> update({
    required String id,
    String? name,
    String? description,
    int? pricePaise,
    ProductCategory? category,
    VegStatus? vegStatus,
    bool? isSpicy,
    bool? isBestseller,
    bool? isNew,
    int? displayOrder,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/products/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (pricePaise != null) 'pricePaise': pricePaise,
        if (category != null) 'category': category.value,
        if (vegStatus != null) 'vegStatus': vegStatus.value,
        if (isSpicy != null) 'isSpicy': isSpicy,
        if (isBestseller != null) 'isBestseller': isBestseller,
        if (isNew != null) 'isNew': isNew,
        if (displayOrder != null) 'displayOrder': displayOrder,
      },
    );
    return _parseOne(response.data!);
  }

  Future<void> delete(String id) async {
    final response = await _dio.delete<Map<String, dynamic>>('/products/$id');
    _ensureSuccess(response.data!);
  }

  Future<ProductModel> setSoldOut(String id, {required bool soldOut}) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/products/$id/sold-out',
      data: {'soldOut': soldOut},
    );
    return _parseOne(response.data!);
  }

  /// POST /api/products/{id}/photos — multipart upload; 4 photos auto-submit draft.
  Future<UploadPhotoResult> uploadPhoto({
    required String productId,
    required List<int> bytes,
    required String filename,
    required PhotoAngleType angleType,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'angleType': angleType.value,
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/products/$productId/photos',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final envelope = response.data!;
    _ensureSuccess(envelope);

    final data = envelope['data'] as Map<String, dynamic>;
    final photoJson = data['photo'] as Map<String, dynamic>;
    final autoSubmitted = data['autoSubmitted'] as bool? ?? false;
    final productJson = data['product'] as Map<String, dynamic>?;

    return UploadPhotoResult(
      photo: ProductPhotoModel.fromJson(photoJson),
      autoSubmitted: autoSubmitted,
      product: productJson != null ? ProductModel.fromJson(productJson) : null,
      message: envelope['message'] as String?,
    );
  }

  /// POST /api/products/{id}/model — direct upload of .glb 3D model.
  Future<ProductModel> uploadModel({
    required String productId,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/products/$productId/model',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _parseOne(response.data!);
  }

  /// POST /api/products/{id}/video — walkaround video (under 35MB).
  Future<ProductModel> uploadVideo({
    required String productId,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      '/products/$productId/video',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _parseOne(response.data!);
  }

  List<ProductModel> _parseList(Map<String, dynamic> envelope) {
    _ensureSuccess(envelope);
    final data = envelope['data'] as List<dynamic>;
    return data
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  ProductModel _parseOne(Map<String, dynamic> envelope) {
    _ensureSuccess(envelope);
    return ProductModel.fromJson(envelope['data'] as Map<String, dynamic>);
  }

  void _ensureSuccess(Map<String, dynamic> envelope) {
    if (envelope['success'] != true) {
      throw Exception(envelope['error'] ?? 'Product request failed');
    }
  }
}
