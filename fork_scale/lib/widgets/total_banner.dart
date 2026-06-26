import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../l10n/app_localizations.dart';

/// The big primary-coloured "NNNN kcal" banner shown at the top of the results
/// and meal-edit screens. Shared so the two stay visually identical.
class TotalBanner extends StatelessWidget {
  final double totalKcal;
  const TotalBanner({super.key, required this.totalKcal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            '${totalKcal.round()}',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 56,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            AppLocalizations.of(context).unitKcal,
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
