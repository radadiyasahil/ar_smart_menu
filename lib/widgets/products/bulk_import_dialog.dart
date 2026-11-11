import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/menu_bulk_import_service.dart';
import '../../core/utils/api_error_utils.dart';
import '../../providers/product_provider.dart';
import '../common/veg_status_badge.dart';

class BulkImportDialog extends StatefulWidget {
  const BulkImportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BulkImportDialog(),
    );
  }

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final TextEditingController _textMenuController = TextEditingController();
  final TextEditingController _searchFilterController = TextEditingController();

  List<ParsedMenuDishItem> _parsedDishes = [];
  String _selectedCategoryFilter = 'All';
  bool _isImporting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tabController.dispose();
    _textMenuController.dispose();
    _searchFilterController.dispose();
    super.dispose();
  }

  Future<void> _pickCsvFile() async {
    setState(() => _errorMessage = null);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        setState(() => _errorMessage = 'The selected file is empty.');
        return;
      }

      final dishes = MenuBulkImportService.instance.parseCsv(utf8.decode(bytes));
      if (dishes.isEmpty) {
        setState(() => _errorMessage = 'No valid dishes found. Please check file format.');
        return;
      }

      setState(() {
        _parsedDishes = dishes;
        _selectedCategoryFilter = 'All';
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to read file: $e');
    }
  }

  void _parsePastedMenuText() {
    setState(() => _errorMessage = null);
    final text = _textMenuController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please enter or paste menu card text.');
      return;
    }

    final dishes = MenuBulkImportService.instance.parseMenuCardText(text);
    if (dishes.isEmpty) {
      setState(() => _errorMessage =
          'Could not detect items and prices. (e.g. Margherita Pizza 249).');
      return;
    }

    setState(() {
      _parsedDishes = dishes;
      _selectedCategoryFilter = 'All';
    });
  }

  void _loadSampleMenuText() {
    _textMenuController.text = MenuBulkImportService.sampleMenuText;
    _parsePastedMenuText();
  }

  Future<void> _executeImport() async {
    final selectedDishes = _parsedDishes.where((d) => d.isSelected).toList();
    if (selectedDishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 dish to import.')),
      );
      return;
    }

    setState(() => _isImporting = true);
    try {
      final items = selectedDishes.map((d) => d.toBulkItem()).toList();
      final result = await context.read<ProductProvider>().bulkCreateProducts(items);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Successfully imported ${result.createdCount} dishes! All dishes are now LIVE.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _errorMessage = formatApiError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E2029) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 860,
        height: size.height * 0.88,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: AppSpacing.md),
            if (_parsedDishes.isEmpty) ...[
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primaryOrange,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_outlined, size: 20), text: 'Excel / CSV File'),
                  Tab(icon: Icon(Icons.document_scanner_outlined, size: 20), text: 'AI Menu Card / Text Scanner'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_errorMessage != null) _buildErrorBanner(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCsvTab(isDark),
                    _buildTextScannerTab(isDark),
                  ],
                ),
              ),
            ] else
              Expanded(child: _buildReviewTable(isDark)),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bolt_rounded, color: AppColors.primaryOrange, size: 26),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fast Menu Importer (200+ Dishes in Seconds)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Upload Excel/CSV or paste physical menu text. Standard items go live immediately.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : AppColors.mediumGray),
              ),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildCsvTab(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252837) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1-Click Excel / CSV Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        'Download the template, paste items from your POS, and import.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF34384B) : Colors.white,
                    foregroundColor: AppColors.primaryOrange,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.primaryOrange),
                    ),
                  ),
                  onPressed: () => MenuBulkImportService.instance.downloadSampleCsv(),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download CSV Template'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          InkWell(
            onTap: _pickCsvFile,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.6), width: 2),
                borderRadius: BorderRadius.circular(16),
                color: AppColors.primaryOrange.withValues(alpha: 0.04),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.upload_file_rounded, size: 44, color: AppColors.primaryOrange),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Click to Browse CSV File', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Supports .csv with Category, Name, Price, VegStatus columns',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppColors.mediumGray),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextScannerTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Paste Menu Text / WhatsApp Menu:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
            TextButton.icon(
              onPressed: _loadSampleMenuText,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Try Sample Menu (20+ Items)'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryOrange),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _textMenuController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Example:\n--- PIZZAS ---\nMargherita Pizza 249\nFarmhouse Pizza 349 (Veg)\n\n--- PUNJABI ---\nPaneer Butter Masala 280\nButter Chicken 360',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.black38),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? const Color(0xFF161822) : const Color(0xFFFAFAFA),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _parsePastedMenuText,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Auto-Detect & Structure Dishes'),
        ),
      ],
    );
  }

  Widget _buildReviewTable(bool isDark) {
    final categories = <String>{'All', ..._parsedDishes.map((d) => d.categoryRaw)};
    final query = _searchFilterController.text.trim().toLowerCase();
    final visibleDishes = _parsedDishes.where((d) {
      if (_selectedCategoryFilter != 'All' && d.categoryRaw != _selectedCategoryFilter) return false;
      return query.isEmpty || d.name.toLowerCase().contains(query) || d.categoryRaw.toLowerCase().contains(query);
    }).toList();

    final allSelected = visibleDishes.isNotEmpty && visibleDishes.every((d) => d.isSelected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = categories.elementAt(index);
                    final active = _selectedCategoryFilter == cat;
                    final count = cat == 'All' ? _parsedDishes.length : _parsedDishes.where((d) => d.categoryRaw == cat).length;
                    return FilterChip(
                      selected: active,
                      showCheckmark: false,
                      label: Text('$cat ($count)'),
                      selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? AppColors.primaryOrange : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              height: 38,
              child: TextField(
                controller: _searchFilterController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search parsed...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Checkbox(
              value: allSelected,
              activeColor: AppColors.primaryOrange,
              onChanged: (val) {
                final select = val ?? true;
                setState(() {
                  for (final d in visibleDishes) {
                    d.isSelected = select;
                  }
                });
              },
            ),
            Text(
              'Select All (${_parsedDishes.where((d) => d.isSelected).length}/${_parsedDishes.length} items ready to go LIVE)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              color: isDark ? const Color(0xFF161822) : const Color(0xFFFAFAFA),
            ),
            child: ListView.separated(
              itemCount: visibleDishes.length,
              separatorBuilder: (_, index) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
              itemBuilder: (context, index) {
                final dish = visibleDishes[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: dish.isSelected,
                        activeColor: AppColors.primaryOrange,
                        onChanged: (val) => setState(() => dish.isSelected = val ?? false),
                      ),
                      // Reusable VegStatusBadge
                      VegStatusBadge(vegStatus: dish.vegStatus, size: 15),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(dish.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.black12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(dish.categoryRaw, style: const TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '₹${dish.priceRupees.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryOrange),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.redAccent,
                        tooltip: 'Remove',
                        onPressed: () => setState(() => _parsedDishes.remove(dish)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_parsedDishes.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() => _parsedDishes = []),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to File / Text Upload'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mediumGray),
          )
        else
          const SizedBox.shrink(),
        Row(
          children: [
            OutlinedButton(
              onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (_parsedDishes.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: _isImporting ? null : _executeImport,
                icon: _isImporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(
                  _isImporting
                      ? 'Importing Dishes...'
                      : 'Import ${_parsedDishes.where((d) => d.isSelected).length} Dishes Live',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
