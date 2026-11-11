import 'dart:convert';
import '../../models/product_model.dart';
import 'product_service.dart';
import 'receipt_stub_helper.dart'
    if (dart.library.js_interop) 'receipt_web_helper.dart' as platform_helper;

class ParsedMenuDishItem {
  ParsedMenuDishItem({
    required this.name,
    this.category = ProductCategory.mainCourse,
    this.categoryRaw = 'Main Course',
    this.priceRupees = 199,
    this.vegStatus = VegStatus.veg,
    this.description = '',
    this.isSpicy = false,
    this.isBestseller = false,
    this.isSelected = true,
  });

  String name;
  ProductCategory category;
  String categoryRaw;
  double priceRupees;
  VegStatus vegStatus;
  String description;
  bool isSpicy;
  bool isBestseller;
  bool isSelected;

  BulkCreateProductItem toBulkItem() => BulkCreateProductItem(
        name: name.trim(),
        description: description.trim().isEmpty ? null : description.trim(),
        pricePaise: (priceRupees * 100).round(),
        category: category,
        vegStatus: vegStatus,
        isSpicy: isSpicy,
        isBestseller: isBestseller,
        isNew: true,
      );
}

class MenuBulkImportService {
  MenuBulkImportService._();
  static final MenuBulkImportService instance = MenuBulkImportService._();

  static const String sampleMenuText = '''
--- PIZZAS ---
Margherita Pizza 249 (Veg, Bestseller)
Farmhouse Supreme 349 (Veg)
Paneer Makhani Pizza 379 (Veg, Spicy)
Chicken Pepperoni Pizza 399 (Non-Veg, Bestseller)
BBQ Smoked Chicken Pizza 420 (Non-Veg)

--- PUNJABI SPECIALS ---
Paneer Butter Masala 280 (Veg, Bestseller)
Dal Makhani 220 (Veg)
Kadhai Paneer 290 (Veg, Spicy)
Butter Chicken 360 (Non-Veg, Bestseller)
Chicken Tikka Masala 380 (Non-Veg, Spicy)
Garlic Butter Naan 60 (Veg)
Tandoori Roti 25 (Veg)
Jeera Rice 160 (Veg)

--- ICE CREAM & DESSERTS ---
Belgian Dark Chocolate 140 (Veg, Bestseller)
Alphonso Mango Scoop 120 (Veg)
Sizzling Brownie with Ice Cream 190 (Veg, Bestseller)
Gulab Jamun with Ice Cream 130 (Veg)
Oreo Choco Fudge Sundae 170 (Veg)

--- BEVERAGES ---
Fresh Mint Mojito 150 (Veg, Bestseller)
Cold Coffee with Ice Cream 140 (Veg)
Fresh Lime Soda 80 (Veg)
Iced Lemon Tea 110 (Veg)''';

  static final _categoryKeywords = <ProductCategory, List<String>>{
    ProductCategory.starter: ['starter', 'appetizer', 'soup', 'salad', 'kebab', 'tikka', 'crispy'],
    ProductCategory.dessert: ['dessert', 'ice cream', 'sweet', 'pastry', 'cake', 'brownie', 'halwa', 'kulfi', 'jamun'],
    ProductCategory.beverage: ['beverage', 'drink', 'shake', 'mojito', 'coffee', 'tea', 'juice', 'mocktail', 'soda'],
    ProductCategory.bread: ['bread', 'roti', 'naan', 'paratha', 'kulcha'],
    ProductCategory.snack: ['snack', 'chaat', 'burger', 'sandwich', 'fries', 'pizza', 'pasta'],
    ProductCategory.combo: ['combo', 'thali', 'platter'],
  };

  /// Generates CSV template content from sample menu items
  String generateSampleCsv() {
    final buffer = StringBuffer('Category,Name,Price,VegStatus,Description,IsSpicy,IsBestseller\n');
    final dishes = parseMenuCardText(sampleMenuText);
    for (final d in dishes) {
      final spicy = d.isSpicy ? 'Yes' : 'No';
      final best = d.isBestseller ? 'Yes' : 'No';
      final veg = d.vegStatus == VegStatus.nonVeg ? 'Non-Veg' : 'Veg';
      buffer.writeln('${d.categoryRaw},${d.name},${d.priceRupees.toInt()},$veg,,$spicy,$best');
    }
    return buffer.toString();
  }

  /// Downloads sample CSV directly in the browser
  void downloadSampleCsv() {
    platform_helper.downloadTextFile(
      generateSampleCsv(),
      'ar_smart_menu_template.csv',
    );
  }

  /// Parses CSV file contents into dishes
  List<ParsedMenuDishItem> parseCsv(String csvText) {
    final clean = csvText.replaceAll('\uFEFF', '').trim();
    if (clean.isEmpty) return [];

    final lines = const LineSplitter().convert(clean);
    if (lines.isEmpty) return [];

    final dishes = <ParsedMenuDishItem>[];
    final headerOffset = lines[0].toLowerCase().contains('name') ? 1 : 0;

    for (var i = headerOffset; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line);
      if (cols.length < 2) continue;

      final catRaw = cols[0].trim();
      final name = cols[1].trim();
      if (name.isEmpty) continue;

      final price = _extractPrice(cols.length > 2 ? cols[2] : '0');
      final veg = _parseVegStatus(cols.length > 3 ? cols[3] : '', name);
      final desc = cols.length > 4 ? cols[4].trim() : '';
      final spicy = cols.length > 5 && ['yes', 'true', '1'].contains(cols[5].trim().toLowerCase());
      final best = cols.length > 6 && ['yes', 'true', '1'].contains(cols[6].trim().toLowerCase());

      dishes.add(ParsedMenuDishItem(
        name: name,
        categoryRaw: catRaw.isEmpty ? 'Main Course' : catRaw,
        category: _smartMapCategory(catRaw, name),
        priceRupees: price,
        vegStatus: veg,
        description: desc,
        isSpicy: spicy,
        isBestseller: best,
      ));
    }

    return dishes;
  }

  /// Structured text parser for paper menu cards / raw OCR text
  List<ParsedMenuDishItem> parseMenuCardText(String rawText) {
    final clean = rawText.replaceAll('\uFEFF', '').trim();
    if (clean.isEmpty) return [];

    final lines = const LineSplitter().convert(clean);
    final dishes = <ParsedMenuDishItem>[];
    String currentCategory = 'Main Course';

    final categoryRegex = RegExp(r'^(?:[-*#=~_\s]{1,4})?([A-Za-z0-9\s&/]{3,35})(?:[-*#=~_\s]{1,4})?$');
    final priceRegex = RegExp(r'(?:₹|rs\.?|inr)?\s*(\d{2,5})(?:\s*\/-\s*|\s*\.\d{2})?', caseSensitive: false);

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || RegExp(r'^[-=*_~]{3,}$').hasMatch(line)) continue;

      final priceMatches = priceRegex.allMatches(line).toList();

      if (priceMatches.isEmpty) {
        final match = categoryRegex.firstMatch(line);
        final candidate = match?.group(1)?.trim();
        if (candidate != null &&
            candidate.length >= 3 &&
            !candidate.toLowerCase().startsWith('total') &&
            !candidate.toLowerCase().startsWith('page')) {
          currentCategory = candidate;
        }
      } else {
        final lastMatch = priceMatches.last;
        final priceVal = double.tryParse(lastMatch.group(1) ?? '0') ?? 0;
        if (priceVal <= 0) continue;

        var namePart = line.substring(0, lastMatch.start).trim();
        namePart = namePart.replaceAll(RegExp(r'^[\d\.\-\*\•\•\>\)]+\s*'), '');
        namePart = namePart.replaceAll(RegExp(r'[\.]{2,}|\-{2,}'), ' ').trim();
        if (namePart.isEmpty && lastMatch.end < line.length) {
          namePart = line.substring(lastMatch.end).trim();
        }
        if (namePart.length < 2) continue;

        final lower = line.toLowerCase();
        dishes.add(ParsedMenuDishItem(
          name: namePart,
          categoryRaw: currentCategory,
          category: _smartMapCategory(currentCategory, namePart),
          priceRupees: priceVal,
          vegStatus: _parseVegStatus(line, namePart),
          isSpicy: ['spicy', 'chilli', 'chili', 'schezwan', 'hot'].any(lower.contains),
          isBestseller: ['chef special', 'bestseller', 'special', 'recommended'].any(lower.contains),
        ));
      }
    }

    return dishes;
  }

  ProductCategory _smartMapCategory(String catStr, String dishName) {
    final combined = '${catStr.toLowerCase()} ${dishName.toLowerCase()}';
    for (final entry in _categoryKeywords.entries) {
      if (entry.value.any(combined.contains)) return entry.key;
    }
    return ProductCategory.mainCourse;
  }

  VegStatus _parseVegStatus(String text, String name) {
    final lower = '${text.toLowerCase()} ${name.toLowerCase()}';
    if (lower.contains('vegan')) return VegStatus.vegan;
    if (['non-veg', 'nonveg', 'chicken', 'mutton', 'fish', 'prawn', 'egg', 'meat', '🔴'].any(lower.contains)) {
      return VegStatus.nonVeg;
    }
    return VegStatus.veg;
  }

  double _extractPrice(String raw) =>
      double.tryParse(raw.replaceAll(RegExp(r'[^\d\.]'), '')) ?? 0.0;

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }
}
