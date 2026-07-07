---
name: project-ui-redesign
description: Soft Neo-Brutalist UI redesign completed — design system files created, all screens updated
metadata:
  type: project
---

## UI Redesign — Soft Neo-Brutalist Design System

A full UI/UX redesign was completed on 2026-06-04.

**Why:** User requested a production-quality Soft Neo-Brutalist redesign across all screens while preserving all business logic, Firebase, Stripe, and location integrations.

**How to apply:** All new UI must use AppColors and WcComponents. Do not reintroduce inline Color() literals or old orange/grey color scheme.

### New Files Created
- `lib/core/theme/app_colors.dart` — centralized color tokens
- `lib/core/theme/app_theme.dart` — MaterialApp ThemeData (Material 3)
- `lib/shared/widgets/wc_components.dart` — reusable Neo-Brutalist components

### Design System Rules
- Background: `AppColors.background` (#FAFAF8 warm off-white)
- Surface/cards: `AppColors.surface` (#FFFFFF) with 1.5px `AppColors.border` border + 3px hard offset shadow
- Primary: `AppColors.primary` (#EA580C deep orange)
- No emojis anywhere in the UI
- No blurred soft shadows — use hard offset `BoxShadow(color: AppColors.shadow, offset: Offset(3,3), blurRadius: 0)`
- All print() replaced with debugPrint()

### Screens Redesigned
1. login_screen.dart
2. customer_landing_page.dart (preserves JobLiveMap, _CreateJobDialog, stream builders)
3. worker_landing_page.dart
4. admin_panel_screen.dart
5. worker_registration_screen.dart
6. worker_dashboard_screen.dart
7. worker_list_screen.dart
8. submit_review_screen.dart

### Key Components (wc_components.dart)
- `WcCard` — bordered card with hard offset shadow
- `WcPrimaryButton` / `WcOutlinedButton` — Neo-Brutalist buttons
- `WcStatusBadge` — small pill label
- `WcSectionHeader` — bold section heading
- `WcEmptyState` — icon + text empty state
- `WcNotice` — info/warning/error banner
- `WcStatCard` — metric card
- `WcActionRow` — list-item action
- `WcSkeleton` — animated loading placeholder
- `WcAppBar` — AppBar with 2px bottom border
