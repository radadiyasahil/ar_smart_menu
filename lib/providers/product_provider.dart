import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/auth_service.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/product_service.dart';
import '../core/utils/api_error_utils.dart';
import '../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider({
    ProductService? productService,
    AuthService? authService,
  })  : _productService = productService ?? ProductService(),
        _authService = authService ?? AuthService();

  final ProductService _productService;
  final AuthService _authService;

  List<ProductModel> _products = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isLoaded = false;
  String? _error;

  List<ProductModel> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isLoaded => _isLoaded;
  String? get error => _error;

  int get totalCount => _products.length;
  int get liveCount => _products.where((p) => p.isLive).length;

  List<ProductModel> get recentProducts =>
      _products.take(5).toList(growable: false);

  /// Instant startup from local storage.
  Future<void> hydrateFromCache() async {
    _products = await LocalCacheService.loadProducts();
    _isLoaded = _products.isNotEmpty;
    notifyListeners();
  }

  Future<void> _persistProducts() async {
    await LocalCacheService.saveProducts(_products);
  }

  /// Load from API when user opens Products/Dashboard.
  /// [background]: show cache first, fetch quietly.
  /// [force]: ignore freshness and refetch.
  Future<void> loadProducts({bool force = false, bool background = false}) async {
    if (_isLoading || _isSyncing) return;

    if (!force && !background && _isLoaded) return;

    if (background && !force) {
      if (await LocalCacheService.isProductsFresh() && _products.isNotEmpty) {
        return;
      }
      return _syncProducts(showLoading: false);
    }

    if (!force && _isLoaded && _products.isNotEmpty) {
      return;
    }

    await _syncProducts(showLoading: true);
  }

  Future<void> _syncProducts({required bool showLoading}) async {
    if (showLoading) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    } else {
      _isSyncing = true;
      notifyListeners();
    }

    try {
      _products = await _productService.list();
      _isLoaded = true;
      _error = null;
      await _persistProducts();
    } catch (e) {
      final message = formatApiError(e);
      if (message.contains('No business linked')) {
        await _refreshAuthToken();
        try {
          _products = await _productService.list();
          _isLoaded = true;
          _error = null;
          await _persistProducts();
        } catch (retryError) {
          if (_products.isEmpty) _error = formatApiError(retryError);
        }
      } else if (_products.isEmpty) {
        _error = message;
      }
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<ProductModel> createProduct({
    required String name,
    String? description,
    int? pricePaise,
    ProductCategory? category,
    VegStatus vegStatus = VegStatus.notApplicable,
    bool isSpicy = false,
    bool isBestseller = false,
    bool isNew = false,
  }) async {
    final product = await _productService.create(
      name: name,
      description: description,
      pricePaise: pricePaise,
      category: category,
      vegStatus: vegStatus,
      isSpicy: isSpicy,
      isBestseller: isBestseller,
      isNew: isNew,
    );
    _products = [product, ..._products];
    _isLoaded = true;
    await _persistProducts();
    notifyListeners();
    return product;
  }

  Future<ProductModel> updateProduct({
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
    final updated = await _productService.update(
      id: id,
      name: name,
      description: description,
      pricePaise: pricePaise,
      category: category,
      vegStatus: vegStatus,
      isSpicy: isSpicy,
      isBestseller: isBestseller,
      isNew: isNew,
      displayOrder: displayOrder,
    );
    _replaceLocal(updated);
    await _persistProducts();
    return updated;
  }

  Future<void> deleteProduct(String id) async {
    await _productService.delete(id);
    _products = _products.where((p) => p.id != id).toList();
    await _persistProducts();
    notifyListeners();
  }

  Future<ProductModel> toggleSoldOut(String id, {required bool soldOut}) async {
    final updated = await _productService.setSoldOut(id, soldOut: soldOut);
    _replaceLocal(updated);
    await _persistProducts();
    return updated;
  }

  Future<void> reorderProducts(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final updated = await _productService.update(
        id: orderedIds[i],
        displayOrder: i,
      );
      _replaceLocal(updated);
    }
    _products.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    await _persistProducts();
    notifyListeners();
  }

  Future<int> bulkSetSoldOut(
    Iterable<String> ids, {
    required bool soldOut,
  }) async {
    var count = 0;
    for (final id in ids) {
      final updated = await _productService.setSoldOut(id, soldOut: soldOut);
      _replaceLocal(updated);
      count++;
    }
    await _persistProducts();
    notifyListeners();
    return count;
  }

  List<ProductModel> sortedByMenuOrder() {
    final copy = List<ProductModel>.of(_products);
    copy.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return copy;
  }

  Future<ProductModel> fetchProduct(String id) async {
    final product = await _productService.getById(id);
    _replaceLocal(product);
    await _persistProducts();
    return product;
  }

  Future<UploadPhotoResult> uploadPhoto({
    required String productId,
    required List<int> bytes,
    required String filename,
    required PhotoAngleType angleType,
  }) async {
    final result = await _productService.uploadPhoto(
      productId: productId,
      bytes: bytes,
      filename: filename,
      angleType: angleType,
    );

    final updated = result.product ?? await _productService.getById(productId);
    _replaceLocal(updated);
    await _persistProducts();
    return UploadPhotoResult(
      photo: result.photo,
      autoSubmitted: result.autoSubmitted,
      product: updated,
      message: result.message,
    );
  }

  Future<ProductModel> uploadModel({
    required String productId,
    required List<int> bytes,
    required String filename,
  }) async {
    final updated = await _productService.uploadModel(
      productId: productId,
      bytes: bytes,
      filename: filename,
    );
    _replaceLocal(updated);
    await _persistProducts();
    return updated;
  }

  Future<ProductModel> uploadVideo({
    required String productId,
    required List<int> bytes,
    required String filename,
  }) async {
    final updated = await _productService.uploadVideo(
      productId: productId,
      bytes: bytes,
      filename: filename,
    );
    _replaceLocal(updated);
    await _persistProducts();
    return updated;
  }

  void clear() {
    _products = [];
    _isLoaded = false;
    _error = null;
    notifyListeners();
  }

  void _replaceLocal(ProductModel updated) {
    final index = _products.indexWhere((p) => p.id == updated.id);
    if (index >= 0) {
      _products = List.of(_products)..[index] = updated;
    } else {
      _products = [updated, ..._products];
    }
    notifyListeners();
  }

  Future<void> _refreshAuthToken() async {
    final token = await _authService.refreshToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
