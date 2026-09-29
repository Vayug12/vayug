import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:vayug/core/design/colors.dart';
import 'package:vayug/core/design/typography.dart';

class CommentAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double size;

  const CommentAvatar({super.key, this.imageUrl, this.name, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final initial = name?.trim().characters.firstOrNull;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.backgroundTertiary,
        shape: BoxShape.circle,
      ),
      child: initial == null
          ? const Icon(Icons.person_outline_rounded,
              size: 18, color: AppColors.textSecondary)
          : Text(initial.toUpperCase(), style: AppTypography.labelLarge),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
