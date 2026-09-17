import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Minimal video-only surface for picture-in-picture mode.
/// Overlays and interaction controls are omitted inside the small system PiP window.
class FeedPipPlayer extends StatelessWidget {
  final VideoPlayerController? controller;
  final double aspectRatio;

  const FeedPipPlayer({
    Key? key,
    required this.controller,
    required this.aspectRatio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: controller != null && controller!.value.isInitialized
          ? Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(controller!),
              ),
            )
          : const ColoredBox(color: Colors.black),
    );
  }
}
