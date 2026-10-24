import 'package:flutter/material.dart';
import '../../widgets/common/hover_card.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/api_error_utils.dart';
import '../../models/product_model.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';

enum ProductListFilter {
  all('All'),
  live('Live'),
  draft('Draft'),
  processing('Processing'),
  rejected('Rejected');

  const ProductListFilter(this.label);
  final String label;
}

enum ProductListSort {
  menuOrder('Menu order'),
  name('Name'),
  newest('Newest');

  const ProductListSort(this.label);
  final String label;
}

/// Owner product list — filter, reorder, bulk sold-out, menu order.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  ProductListFilter _filter = ProductListFilter.all;
  ProductListSort _sort = ProductListSort.menuOrder;
  bool _bulkMode = false;
  final Set<String> _selectedIds = {};
  bool _isBulkWorking = false;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = context.read<BusinessProvider>();
      if (business.isActive) {
        context.read<ProductProvider>().loadProducts(background: true);
      }
    });
  }

  List<ProductModel> _visibleProducts(ProductProvider provider) {
    var list = provider.sortedByMenuOrder();

    list = switch (_filter) {
      ProductListFilter.all => list,
      ProductListFilter.live =>
        list.where((p) => p.status == ProductStatus.live).toList(),
      ProductListFilter.draft =>
        list.where((p) => p.status == ProductStatus.draft).toList(),
      ProductListFilter.processing => list
          .where((p) =>
              p.status == ProductStatus.processing ||
              p.status == ProductStatus.submitted ||
              p.status == ProductStatus.review)
          .toList(),
      ProductListFilter.rejected =>
        list.where((p) => p.status == ProductStatus.rejected).toList(),
    };

    list = switch (_sort) {
      ProductListSort.menuOrder => list
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
      ProductListSort.name => list
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      ProductListSort.newest => list
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        }),
    };

    return list;
  }

  Future<void> _onReorder(ProductProvider provider, int oldIndex, int newIndex) async {
    if (_sort != ProductListSort.menuOrder) return;
    final items = _visibleProducts(provider);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    setState(() => _isReordering = true);
    try {
      await provider.reorderProducts(items.map((p) => p.id).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isReordering = false);
    }
  }

  Future<void> _bulkSoldOut(ProductProvider provider, bool soldOut) async {
    if (_selectedIds.isEmpty) return;
    setState(() => _isBulkWorking = true);
    try {
      final count = await provider.bulkSetSoldOut(
        _selectedIds,
        soldOut: soldOut,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              soldOut
                  ? 'Marked $count item(s) sold out'
                  : 'Cleared sold out on $count item(s)',
            ),
          ),
        );
        setState(() {
          _bulkMode = false;
          _selectedIds.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatApiError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isBulkWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BusinessProvider, ProductProvider>(
      builder: (context, businessProvider, productProvider, _) {
        if (!businessProvider.isActive) {
          return _InactiveBusinessView(businessProvider: businessProvider);
        }

        final products = _visibleProducts(productProvider);
        final canReorder =
            _sort == ProductListSort.menuOrder &&
            _filter == ProductListFilter.all &&
            !_bulkMode;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Products'),
            actions: [
              if (_bulkMode) ...[
                TextButton(
                  onPressed: _isBulkWorking
                      ? null
                      : () => _bulkSoldOut(productProvider, true),
                  child: const Text('Sold out'),
                ),
                TextButton(
                  onPressed: _isBulkWorking
                      ? null
                      : () => _bulkSoldOut(productProvider, false),
                  child: const Text('Available'),
                ),
              ],
              IconButton(
                tooltip: _bulkMode ? 'Done selecting' : 'Bulk sold-out',
                icon: Icon(_bulkMode ? Icons.close : Icons.checklist),
                onPressed: () {
                  setState(() {
                    _bulkMode = !_bulkMode;
                    _selectedIds.clear();
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: productProvider.isLoading
                    ? null
                    : () => productProvider.loadProducts(force: true),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push(AppRoutes.addProduct),
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: AppColors.white,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterSortBar(
                filter: _filter,
                sort: _sort,
                onFilterChanged: (value) => setState(() => _filter = value),
                onSortChanged: (value) => setState(() => _sort = value),
              ),
              if (canReorder)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    _isReordering
                        ? 'Saving menu order...'
                        : 'Long-press and drag to reorder your menu',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
              Expanded(child: _buildBody(productProvider, products, canReorder)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(
    ProductProvider provider,
    List<ProductModel> products,
    bool canReorder,
  ) {
    if (provider.isLoading && !provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => provider.loadProducts(force: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (products.isEmpty && !provider.isSyncing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _filter == ProductListFilter.all
                    ? 'No products yet'
                    : 'No ${_filter.label.toLowerCase()} products',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (canReorder) {
      return RefreshIndicator(
        onRefresh: () => provider.loadProducts(force: true),
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            88,
          ),
          itemCount: products.length,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(provider, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductListTile(
              key: ValueKey(product.id),
              product: product,
              listIndex: index,
              bulkMode: _bulkMode,
              selected: _selectedIds.contains(product.id),
              showDragHandle: true,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedIds.add(product.id);
                  } else {
                    _selectedIds.remove(product.id);
                  }
                });
              },
              onTap: () => context.push(AppRoutes.productDetail(product.id)),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadProducts(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          88,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _ProductListTile(
            key: ValueKey(product.id),
            product: product,
            bulkMode: _bulkMode,
            selected: _selectedIds.contains(product.id),
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedIds.add(product.id);
                } else {
                  _selectedIds.remove(product.id);
                }
              });
            },
            onTap: () => context.push(AppRoutes.productDetail(product.id)),
          );
        },
      ),
    );
  }
}

class _FilterSortBar extends StatelessWidget {
  const _FilterSortBar({
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final ProductListFilter filter;
  final ProductListSort sort;
  final ValueChanged<ProductListFilter> onFilterChanged;
  final ValueChanged<ProductListSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ProductListFilter.values.map((option) {
                final selected = filter == option;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(option.label),
                    selected: selected,
                    onSelected: (_) => onFilterChanged(option),
                    selectedColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.sort, size: 18, color: AppColors.mediumGray),
              const SizedBox(width: AppSpacing.sm),
              DropdownButton<ProductListSort>(
                value: sort,
                underline: const SizedBox.shrink(),
                items: ProductListSort.values
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InactiveBusinessView extends StatelessWidget {
  const _InactiveBusinessView({required this.businessProvider});

  final BusinessProvider businessProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top, size: 56, color: AppColors.warning),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Business not active yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: () => context.go(AppRoutes.businessStatus),
                child: const Text('Check status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  const _ProductListTile({
    super.key,
    required this.product,
    required this.onTap,
    this.listIndex = 0,
    this.bulkMode = false,
    this.selected = false,
    this.showDragHandle = false,
    this.onSelected,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final int listIndex;
  final bool bulkMode;
  final bool selected;
  final bool showDragHandle;
  final ValueChanged<bool>? onSelected;

  Color _statusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.live:
        return AppColors.success;
      case ProductStatus.draft:
        return AppColors.mediumGray;
      case ProductStatus.rejected:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      borderRadius: AppSpacing.radiusMd,
      margin: const EdgeInsets.only(bottom: 12),
      onTap: bulkMode ? () => onSelected?.call(!selected) : onTap,
      borderColor: selected ? AppColors.primaryOrange : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
            children: [
              if (bulkMode)
                Checkbox(
                  value: selected,
                  onChanged: (value) => onSelected?.call(value ?? false),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              if (showDragHandle) ...[
                ReorderableDragStartListener(
                  index: listIndex,
                  child: const Icon(Icons.drag_handle, color: AppColors.mediumGray),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  image: product.thumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(product.thumbnailUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.thumbnailUrl == null
                    ? Icon(Icons.restaurant, color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${product.priceLabel} • ${product.category?.label ?? 'Uncategorized'}',
                      style: const TextStyle(
                        color: AppColors.mediumGray,
                        fontSize: 13,
                      ),
                    ),
                    if (product.soldOutToday)
                      const Text(
                        'Sold out today',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(product.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  product.status.label,
                  style: TextStyle(
                    color: _statusColor(product.status),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
