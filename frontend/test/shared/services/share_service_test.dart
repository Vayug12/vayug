import 'package:flutter_test/flutter_test.dart';
import 'package:vayug/features/ads/data/carousel_ad_model.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/shared/services/share_service.dart';

void main() {
  late ShareService shareService;
  late VideoModel testVideo;

  setUp(() {
    shareService = ShareService();
    testVideo = VideoModel(
      id: '507f1f77bcf86cd799439011',
      videoName: 'Morning Yoga Flow',
      videoUrl: 'https://example.com/video.mp4',
      thumbnailUrl: 'https://example.com/thumb.jpg',
      likes: 10,
      views: 100,
      shares: 5,
      uploader: Uploader(id: 'u1', name: 'Instructor', profilePic: ''),
      uploadedAt: DateTime(2026, 1, 1),
      likedBy: const [],
      videoType: 'vayu',
      aspectRatio: 16 / 9,
      duration: const Duration(minutes: 10),
    );
  });

  group('ShareService.generateVideoShareText', () {
    test('returns clean URL only for full video without marketing boilerplate', () {
      final text = shareService.generateVideoShareText(testVideo);

      expect(
        text,
        'https://snehayog.site/video/507f1f77bcf86cd799439011/morning-yoga-flow',
      );
      expect(text, isNot(contains('Watch')));
      expect(text, isNot(contains('on Vayug')));
    });

    test('returns title and timestamp range on separate line for section shares', () {
      final text = shareService.generateVideoShareText(
        testVideo,
        startAt: const Duration(seconds: 15),
        endAt: const Duration(seconds: 75),
      );

      expect(
        text,
        'Morning Yoga Flow (00:15 – 01:15)\nhttps://snehayog.site/video/507f1f77bcf86cd799439011/morning-yoga-flow?t=15&end=75',
      );
      expect(text, isNot(contains('Watch the shared section')));
    });

    test('returns title and start timestamp when only startAt is specified', () {
      final text = shareService.generateVideoShareText(
        testVideo,
        startAt: const Duration(seconds: 90),
      );

      expect(
        text,
        'Morning Yoga Flow (from 01:30)\nhttps://snehayog.site/video/507f1f77bcf86cd799439011/morning-yoga-flow?t=90',
      );
    });

    test('formats hours correctly for long videos in section timestamp', () {
      final text = shareService.generateVideoShareText(
        testVideo,
        startAt: const Duration(hours: 1, minutes: 2, seconds: 3),
        endAt: const Duration(hours: 1, minutes: 5, seconds: 30),
      );

      expect(
        text,
        startsWith('Morning Yoga Flow (1:02:03 – 1:05:30)'),
      );
    });
  });

  group('ShareService.generateAdShareText', () {
    test('returns clean ad title and link without marketing boilerplate', () {
      final ad = CarouselAdModel(
        id: 'ad-1',
        campaignId: 'camp-1',
        advertiserName: 'Eco Yoga Mats',
        advertiserProfilePic: '',
        slides: [
          CarouselSlide(
            id: 'slide-1',
            mediaUrl: 'https://example.com/mat.jpg',
            title: 'Premium Yoga Mat',
            description: 'Eco friendly mat',
            mediaType: 'image',
            aspectRatio: '9:16',
          ),
        ],
        callToActionLabel: 'Buy Now',
        callToActionUrl: 'https://snehayog.site/ad/mats',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final text = shareService.generateAdShareText(ad);

      expect(text, 'Premium Yoga Mat\nhttps://snehayog.site/ad/mats');
      expect(text, isNot(contains('Check out this ad on Vayu:')));
    });

    test('returns title only when callToActionUrl is empty', () {
      final ad = CarouselAdModel(
        id: 'ad-2',
        campaignId: 'camp-2',
        advertiserName: 'Brand',
        advertiserProfilePic: '',
        slides: [
          CarouselSlide(
            id: 'slide-2',
            mediaUrl: 'https://example.com/img.jpg',
            title: 'Awesome Deal',
            description: 'Limited time',
            mediaType: 'image',
            aspectRatio: '9:16',
          ),
        ],
        callToActionLabel: 'View',
        callToActionUrl: '',
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final text = shareService.generateAdShareText(ad);

      expect(text, 'Awesome Deal');
    });
  });
}
