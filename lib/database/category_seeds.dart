import 'tables.dart';

/// One seeded category. [key] is the stable l10n key (see
/// `AppStrings.categoryName`); [icon] is a Material icon name resolved by
/// `categoryIconFor`; [color] is an ARGB hex string.
class CategorySeed {
  final String key;
  final CategoryType type;
  final String icon;
  final String color;
  final bool isEssential;

  /// Seed-set version that introduced this category (see
  /// [kCategorySeedVersion]). Lets a later app version add new defaults to an
  /// existing DB without resurrecting defaults the user deleted on purpose.
  final int since;
  const CategorySeed(this.key, this.type, this.icon, this.color, {this.isEssential = false, this.since = 1});
}

/// Bump when adding entries to [defaultCategorySeeds]; give the new entries
/// `since: <new version>`. Stored in AppConfigs under [kCategorySeedVersionKey].
const int kCategorySeedVersion = 2;
const String kCategorySeedVersionKey = 'CATEGORY_SEED_VERSION';

/// Default categories shipped with the app. Order = default [Categories.sortOrder].
///
/// These are CATEGORIES only — no rules are seeded. Classification is always
/// the result of user-defined rules.
const List<CategorySeed> defaultCategorySeeds = [
  // Income
  CategorySeed('salary', CategoryType.income, 'work', 'FF2E7D32'),
  CategorySeed('interestDividends', CategoryType.income, 'percent', 'FF388E3C'),
  CategorySeed('otherIncome', CategoryType.income, 'attach_money', 'FF43A047'),
  // Reimbursement
  CategorySeed('refunds', CategoryType.reimbursement, 'replay', 'FF00897B'),
  // Transfer-like (excluded from spending)
  CategorySeed('transfer', CategoryType.transfer, 'swap_horiz', 'FF607D8B'),
  CategorySeed('investments', CategoryType.transfer, 'trending_up', 'FF455A64'),
  // Expenses
  CategorySeed('groceries', CategoryType.expense, 'shopping_cart', 'FFF57C00', isEssential: true),
  CategorySeed('restaurantsBars', CategoryType.expense, 'restaurant', 'FFE64A19'),
  CategorySeed('transport', CategoryType.expense, 'directions_bus', 'FF1976D2'),
  CategorySeed('carFuelTolls', CategoryType.expense, 'directions_car', 'FF1565C0'),
  CategorySeed('housing', CategoryType.expense, 'home', 'FF6D4C41', isEssential: true),
  CategorySeed('utilities', CategoryType.expense, 'bolt', 'FFFBC02D', isEssential: true),
  CategorySeed('health', CategoryType.expense, 'favorite', 'FFD32F2F', isEssential: true),
  CategorySeed('insurance', CategoryType.expense, 'shield', 'FF5D4037', isEssential: true),
  CategorySeed('shopping', CategoryType.expense, 'shopping_bag', 'FF8E24AA'),
  CategorySeed('subscriptionsEntertainment', CategoryType.expense, 'movie', 'FF7B1FA2'),
  CategorySeed('travel', CategoryType.expense, 'flight', 'FF0288D1'),
  CategorySeed('education', CategoryType.expense, 'school', 'FF00796B'),
  CategorySeed('childcare', CategoryType.expense, 'child_care', 'FFF06292', isEssential: true, since: 2),
  CategorySeed('giftsDonations', CategoryType.expense, 'card_giftcard', 'FFC2185B'),
  CategorySeed('taxesFees', CategoryType.expense, 'account_balance', 'FF616161', isEssential: true),
  CategorySeed('bankFees', CategoryType.expense, 'receipt_long', 'FF757575'),
  CategorySeed('cash', CategoryType.expense, 'payments', 'FF9E9E9E'),
  CategorySeed('other', CategoryType.expense, 'more_horiz', 'FFBDBDBD'),
];
