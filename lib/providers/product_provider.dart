import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import 'auth_provider.dart';

@immutable
class ProductCatalogState {
  final List<ProductCategory> categories;
  final List<ProductModel> products;
  final String? selectedCategoryId;
  final String searchQuery;
  final bool isLoading;
  final String? errorMessage;

  const ProductCatalogState({
    this.categories = const [],
    this.products = const [],
    this.selectedCategoryId,
    this.searchQuery = '',
    this.isLoading = false,
    this.errorMessage,
  });

  /// Daftar produk yang telah difilter berdasarkan kategori dan kata kunci pencarian
  List<ProductModel> get filteredProducts {
    return products.where((product) {
      // 1. Filter Kategori
      if (selectedCategoryId != null && product.categoryId != selectedCategoryId) {
        return false;
      }

      // 2. Filter Search Query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        final matchesName = product.name.toLowerCase().contains(query);
        final matchesSku = product.sku?.toLowerCase().contains(query) ?? false;
        final matchesCategory = product.categoryName?.toLowerCase().contains(query) ?? false;
        if (!matchesName && !matchesSku && !matchesCategory) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  ProductCatalogState copyWith({
    List<ProductCategory>? categories,
    List<ProductModel>? products,
    String? Function()? selectedCategoryId,
    String? searchQuery,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return ProductCatalogState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      selectedCategoryId: selectedCategoryId != null ? selectedCategoryId() : this.selectedCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class ProductCatalogNotifier extends Notifier<ProductCatalogState> {
  @override
  ProductCatalogState build() {
    // Otomatis muat katalog produk saat provider pertama kali diakses
    Future.microtask(() => fetchCatalog());
    return const ProductCatalogState(isLoading: true);
  }

  /// Mengambil data kategori dan produk dari database Supabase
  Future<void> fetchCatalog() async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    try {
      final supaClient = Supabase.instance.client;
      final auth = ref.read(authProvider);
      final storeId = auth.storeId;

      // 1. Ambil Kategori Produk
      var catBuilder = supaClient.from('ProductCategory').select('id, storeId, name');
      if (storeId.isNotEmpty) {
        catBuilder = catBuilder.eq('storeId', storeId);
      }
      final catResponse = await catBuilder.order('name');
      final List<ProductCategory> fetchedCategories = (catResponse as List)
          .map((c) => ProductCategory.fromMap(c as Map<String, dynamic>))
          .toList();

      // 2. Ambil Produk beserta join relasi Varian dan Kategori
      var prodBuilder = supaClient.from('Product').select('''
        id, storeId, categoryId, name, sku, imageUrl, type, price, availability, discontinued,
        category:ProductCategory(name),
        variants:ProductVariant(id, productId, name, sku, price, availability, discontinued)
      ''').eq('discontinued', false);

      if (storeId.isNotEmpty) {
        prodBuilder = prodBuilder.eq('storeId', storeId);
      }
      final prodResponse = await prodBuilder.order('name').limit(500);
      final List<ProductModel> fetchedProducts = (prodResponse as List)
          .map((p) => ProductModel.fromMap(p as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        categories: fetchedCategories,
        products: fetchedProducts,
        isLoading: false,
        errorMessage: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: () => 'Gagal memuat katalog produk: ${e.toString()}',
      );
    }
  }

  /// Pilih filter kategori (null untuk menampilkan 'Semua')
  void selectCategory(String? categoryId) {
    state = state.copyWith(selectedCategoryId: () => categoryId);
  }

  /// Set teks pencarian produk
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final productProvider = NotifierProvider<ProductCatalogNotifier, ProductCatalogState>(
  ProductCatalogNotifier.new,
);
