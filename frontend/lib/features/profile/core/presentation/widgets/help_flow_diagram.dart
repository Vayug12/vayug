import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';

/// One node of a help flow diagram.
class FlowStep {
  const FlowStep(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Icon nodes joined by arrows, displaying the guide visually.
/// The last node represents the outcome and carries the accent color.
class HelpFlow extends StatelessWidget {
  const HelpFlow({
    super.key,
    required this.title,
    required this.steps,
    this.note,
  });

  final String title;
  final List<FlowStep> steps;

  /// Optional footnote text (e.g. when the reward lands).
  final String? note;

  static const double _tileSize = 48;

  @override
  Widget build(BuildContext context) {
    final row = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      if (i > 0) row.add(_buildArrow());
      row.add(
        Expanded(
          child: _buildNode(steps[i], isOutcome: i == steps.length - 1),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: row),
        if (note != null) ...[
          const SizedBox(height: 12),
          Text(
            note!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArrow() {
    return const SizedBox(
      height: _tileSize,
      width: 24,
      child: Center(
        child: Icon(
          Icons.arrow_forward_rounded,
          size: 16,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildNode(FlowStep step, {required bool isOutcome}) {
    return Column(
      children: [
        Container(
          height: _tileSize,
          width: _tileSize,
          decoration: BoxDecoration(
            color: isOutcome
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOutcome
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.borderPrimary,
            ),
          ),
          child: Icon(
            step.icon,
            size: 20,
            color: isOutcome ? AppColors.primaryLight : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          step.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelSmall.copyWith(
            color: isOutcome ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
