import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFFEA580C); // orange-600
  static const Color primaryDark  = Color(0xFFC2410C); // orange-700
  static const Color primaryLight = Color(0xFFFFF7ED); // orange-50

  // ── Surface / Background ───────────────────────────────────────────
  static const Color background  = Color(0xFFFAFAF8); // warm off-white
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceAlt  = Color(0xFFF5F4F2); // slightly tinted

  // ── Borders & Shadows (Neo-Brutalist) ──────────────────────────────
  static const Color border      = Color(0xFF1C1917); // stone-900 — hard border
  static const Color borderLight = Color(0xFFD6D3D1); // stone-300 — subtle divider
  static const Color shadow      = Color(0xFF1C1917); // hard offset shadow

  // ── Text ───────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1C1917); // stone-900
  static const Color textSecondary = Color(0xFF78716C); // stone-500
  static const Color textMuted     = Color(0xFFA8A29E); // stone-400
  static const Color textInverse   = Color(0xFFFFFFFF);

  // ── Status ─────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF16A34A); // green-600
  static const Color successLight = Color(0xFFF0FDF4); // green-50
  static const Color error        = Color(0xFFDC2626); // red-600
  static const Color errorLight   = Color(0xFFFEF2F2); // red-50
  static const Color warning      = Color(0xFFD97706); // amber-600
  static const Color warningLight = Color(0xFFFFFBEB); // amber-50
  static const Color info         = Color(0xFF2563EB); // blue-600
  static const Color infoLight    = Color(0xFFEFF6FF); // blue-50

  // ── Role accent colors ─────────────────────────────────────────────
  static const Color admin       = Color(0xFF7C3AED); // violet-600
  static const Color adminLight  = Color(0xFFF5F3FF); // violet-50
  static const Color worker      = Color(0xFF16A34A); // green-600
  static const Color workerLight = Color(0xFFF0FDF4); // green-50
  static const Color customer    = Color(0xFFEA580C); // orange-600

  // ── Ratings ────────────────────────────────────────────────────────
  static const Color rating = Color(0xFFF59E0B); // amber-500
}
