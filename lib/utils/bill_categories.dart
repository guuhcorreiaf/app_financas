import 'package:flutter/material.dart';

class BillCategoryStyle {
  final String name;
  final IconData icon;
  final Color color;
  final Color softBg;

  const BillCategoryStyle({
    required this.name,
    required this.icon,
    required this.color,
    required this.softBg,
  });
}

class BillCategories {
  static const List<BillCategoryStyle> all = [
    BillCategoryStyle(
      name: 'Moradia',
      icon: Icons.home_outlined,
      color: Color(0xFF0E5A7A),
      softBg: Color(0xFFE6F2F8),
    ),
    BillCategoryStyle(
      name: 'Contas Fixas',
      icon: Icons.bolt_outlined,
      color: Color(0xFF0D7377),
      softBg: Color(0xFFE5F4F4),
    ),
    BillCategoryStyle(
      name: 'Alimentação',
      icon: Icons.restaurant_outlined,
      color: Color(0xFFC26B0E),
      softBg: Color(0xFFFEF3E6),
    ),
    BillCategoryStyle(
      name: 'Cartão',
      icon: Icons.credit_card_outlined,
      color: Color(0xFF7C3AED),
      softBg: Color(0xFFF3EEFF),
    ),
    BillCategoryStyle(
      name: 'Transporte',
      icon: Icons.directions_car_outlined,
      color: Color(0xFF2563EB),
      softBg: Color(0xFFEBF2FF),
    ),
    BillCategoryStyle(
      name: 'Saúde',
      icon: Icons.favorite_border_rounded,
      color: Color(0xFFB91C1C),
      softBg: Color(0xFFFDECEC),
    ),
    BillCategoryStyle(
      name: 'Lazer',
      icon: Icons.celebration_outlined,
      color: Color(0xFFDB2777),
      softBg: Color(0xFFFDF0F6),
    ),
    BillCategoryStyle(
      name: 'Outros',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFF475569),
      softBg: Color(0xFFF1F5F9),
    ),
  ];

  static BillCategoryStyle of(String? category) {
    if (category == null || category.trim().isEmpty) return all.last;
    return all.firstWhere(
      (c) => c.name.toLowerCase() == category.trim().toLowerCase(),
      orElse: () => all.last,
    );
  }
}
