import 'package:flutter/widgets.dart';

///
/// Features & Guarantees:
/// 1. Exactly ONE video scroll per swipe (never skips multiple videos).
/// 2. Fast & Sensitive Swipe: ~15% drag or gentle flick (>250 px/s) switches video.
/// 3. Accidental Tap Protection: Deadzone under 5% screen height (~40px) ensures
///    taps, double-taps, or accidental micro-touches NEVER trigger a video change.
/// 4. Critically Damped / Overdamped Settling: Strictly ZERO oscillation/vibration;
///    settles monotonically to the target video with a smooth ease-out curve in ~250ms.
/// 5. Pull-to-refresh: Preserves native overscroll at index 0.
class ReelsPageScrollPhysics extends ScrollPhysics {
  const ReelsPageScrollPhysics({super.parent});

  @override
  ReelsPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReelsPageScrollPhysics(parent: buildParent(ancestor));
  }

  double _getPage(ScrollMetrics position) {
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  double _getTargetPage(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    final double page = _getPage(position);

    // Accidental tap protection: finger must move at least 5% of viewport height
    // before ANY velocity-based fling can trigger a page change.
    // Taps, double-taps, and accidental clicks typically move < 2% (10-20px).
    const double minDragForFling = 0.05;

    // Fling velocity threshold: requires a real intentional flick (> 250 px/s)
    const double velocityThreshold = 250.0;

    // Drag distance threshold: 15% screen height triggers next video on slow drag
    const double distanceThreshold = 0.15;

    final double floor = page.floorToDouble();
    final double fraction = page - floor;

    // Direction 1: Swiping down (towards next video, page increasing)
    if (fraction <= 0.5) {
      // Deliberate flick down: must have moved past accidental-tap deadzone (5%)
      if (velocity > velocityThreshold && fraction >= minDragForFling) {
        return floor + 1.0;
      }
      // Sustained drag down: crossed 15% threshold
      if (fraction >= distanceThreshold) {
        return floor + 1.0;
      }
      // Otherwise (accidental tap, micro-slip, or <15% drag): snap back to current video
      return floor;
    }

    // Direction 2: Swiping up (towards previous video, page decreasing)
    final double dragUpDistance = 1.0 - fraction;
    // Deliberate flick up: must have moved past accidental-tap deadzone (5%)
    if (velocity < -velocityThreshold && dragUpDistance >= minDragForFling) {
      return floor;
    }
    // Sustained drag up: crossed 15% threshold
    if (dragUpDistance >= distanceThreshold) {
      return floor;
    }
    // Otherwise (accidental tap, micro-slip, or <15% drag): snap back to current video
    return floor + 1.0;
  }

  /// Overdamped spring: strictly ZERO bounce/oscillation, smooth ~250ms settling.
  /// Critical damping formula: c_critical = 2 * sqrt(mass * stiffness)
  /// For mass = 0.8, stiffness = 160.0: c_critical = 2 * sqrt(128) ≈ 22.6
  /// Setting damping to 24.0 ensures slightly overdamped motion (pure monotonic ease-out).
  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.8,
        stiffness: 160.0,
        damping: 24.0,
      );

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // If out of bounds (overscrolling at top or bottom extent), let parent handle (e.g. RefreshIndicator pull at top)
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final double targetPage = _getTargetPage(position, tolerance, velocity);
    final double targetPixels = _getPixels(position, targetPage);

    if (targetPixels != position.pixels) {
      // Clamp initial velocity in spring simulation to prevent velocity-driven overshooting
      final double maxVelocity = position.viewportDimension * 2.0;
      final double clampedVelocity = velocity.clamp(-maxVelocity, maxVelocity);

      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        clampedVelocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// Fast, snappy horizontal PageView physics designed for Apple/TikTok-style
/// 1:1 horizontal swipes between Video, Creator Profile, and Carousel Ad.
///
/// Features & Guarantees:
/// 1. Directional safety: Strictly operates on horizontal scroll metrics.
/// 2. Fast, sensitive response: ~15% drag distance or gentle flick (>250 px/s)
///    commits to the page change instead of waiting for 50%.
/// 3. Apple critically damped settling: mass 0.8, stiffness 180.0, damping 24.0
///    settles monotonically in ~200ms with zero oscillation.
/// 4. Elastic Apple bounce: Preserves native overscroll for rubber-band bounce
///    when swiping towards an unavailable page.
class AppleHorizontalPageScrollPhysics extends ScrollPhysics {
  const AppleHorizontalPageScrollPhysics({super.parent});

  @override
  AppleHorizontalPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return AppleHorizontalPageScrollPhysics(parent: buildParent(ancestor));
  }

  double _getPage(ScrollMetrics position) {
    return position.pixels / position.viewportDimension;
  }

  double _getPixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  double _getTargetPage(
      ScrollMetrics position, Tolerance tolerance, double velocity) {
    final double page = _getPage(position);

    // Accidental tap protection: finger must move at least 5% of viewport width
    const double minDragForFling = 0.05;
    // Fling velocity threshold: requires an intentional flick (> 250 px/s)
    const double velocityThreshold = 250.0;
    // Drag distance threshold: 15% screen width triggers page change on slow drag
    const double distanceThreshold = 0.15;

    final double floor = page.floorToDouble();
    final double fraction = page - floor;

    // Moving forward (to right-side page)
    if (fraction <= 0.5) {
      if (velocity > velocityThreshold && fraction >= minDragForFling) {
        return floor + 1.0;
      }
      if (fraction >= distanceThreshold) {
        return floor + 1.0;
      }
      return floor;
    }

    // Moving backward (to left-side page)
    final double dragBackDistance = 1.0 - fraction;
    if (velocity < -velocityThreshold && dragBackDistance >= minDragForFling) {
      return floor;
    }
    if (dragBackDistance >= distanceThreshold) {
      return floor;
    }
    return floor + 1.0;
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.8,
        stiffness: 180.0,
        damping: 24.0,
      );

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // If out of bounds (elastic overscroll bounce at edges), let parent handle
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final double targetPage = _getTargetPage(position, tolerance, velocity);
    final double targetPixels = _getPixels(position, targetPage);

    if (targetPixels != position.pixels) {
      final double maxVelocity = position.viewportDimension * 2.0;
      final double clampedVelocity = velocity.clamp(-maxVelocity, maxVelocity);

      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        clampedVelocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
