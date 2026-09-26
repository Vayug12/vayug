import 'package:flutter/material.dart';

class VerticalActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final int? count;
  final String? label;

  const VerticalActionButton({
    Key? key,
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
    this.count,
    this.label,
  }) : super(key: key);

  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? statusText = count != null ? _formatCount(count!) : label;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(
                icon,
                color: color,
                size: 28,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 6,
                    offset: Offset(0, 1.5),
                  ),
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          if (statusText != null) ...[
            const SizedBox(height: 2),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black87,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
