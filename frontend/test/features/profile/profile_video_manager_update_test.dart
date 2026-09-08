import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vayug/features/profile/core/presentation/managers/sub_managers/profile_video_manager.dart';
import 'package:vayug/features/video/core/data/models/video_model.dart';
import 'package:vayug/core/interfaces/i_video_service.dart';
import 'package:vayug/core/interfaces/i_auth_service.dart';
import 'package:vayug/shared/managers/smart_cache_manager.dart';

class MockVideoService extends Mock implements IVideoService {}
class MockAuthService extends Mock implements IAuthService {}
class MockSmartCacheManager extends Mock implements SmartCacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProfileVideoManager videoManager;
  late MockVideoService mockVideoService;
  late MockAuthService mockAuthService;
  late MockSmartCacheManager mockCacheManager;

  final testVideo = VideoModel(
    id: 'video_1',
    videoName: 'Test Video',
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
    likes: 10,
    views: 100,
    shares: 5,
    uploadedAt: DateTime.now(),
    uploader: Uploader(id: 'user_1', name: 'Test User', profilePic: ''),
    likedBy: [],
    videoType: 'yog',
    aspectRatio: 9 / 16,
    duration: const Duration(minutes: 1),
    seriesId: null,
    episodes: null,
  );

  setUp(() {
    mockVideoService = MockVideoService();
    mockAuthService = MockAuthService();
    mockCacheManager = MockSmartCacheManager();

    when(() => mockAuthService.getUserData()).thenAnswer((_) async => {
      'id': 'user_1',
      'googleId': 'user_1',
    });

    videoManager = ProfileVideoManager(
      videoService: mockVideoService,
      authService: mockAuthService,
      smartCacheManager: mockCacheManager,
    );
  });

  group('updateVideoInList', () {
    test('should update video seriesId when result comes from EditVideoDetails',
        () async {
      // ARRANGE: Load a video without series data
      when(() => mockVideoService.getUserVideos(
            any(),
            forceRefresh: any(named: 'forceRefresh'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [testVideo]);

      await videoManager.loadUserVideos('user_1');

      expect(videoManager.userVideos, hasLength(1));
      expect(videoManager.userVideos.first.seriesId, isNull);

      // ACT: Simulate what happens when EditVideoDetails pops with result
      // This is the method that SHOULD exist after the fix
      final updatedData = {
        'videoName': 'Test Video',
        'link': '',
        'tags': <String>[],
        'quizzes': <dynamic>[],
        'episodes': [
          {'id': 'video_1', 'videoName': 'Test Video'},
          {'id': 'video_2', 'videoName': 'Episode 2'},
        ],
        'seriesId': 'series_abc',
      };

      // BUG: This method doesn't exist yet - test will FAIL
      videoManager.updateVideoInList('video_1', updatedData);

      // ASSERT: Video should now have series data
      final updatedVideo = videoManager.userVideos.first;
      expect(updatedVideo.seriesId, equals('series_abc'));
      expect(updatedVideo.episodes, isNotNull);
      expect(updatedVideo.episodes, hasLength(2));
    });

    test('should not affect other videos in the list', () async {
      final otherVideo = VideoModel(
        id: 'video_2',
        videoName: 'Other Video',
        videoUrl: 'https://example.com/other.mp4',
        thumbnailUrl: 'https://example.com/other.jpg',
        likes: 5,
        views: 50,
        shares: 2,
        uploadedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        uploader: Uploader(id: 'user_1', name: 'Test User', profilePic: ''),
        likedBy: [],
        videoType: 'yog',
        aspectRatio: 9 / 16,
        duration: const Duration(minutes: 1),
      );

      when(() => mockVideoService.getUserVideos(
            any(),
            forceRefresh: any(named: 'forceRefresh'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [testVideo, otherVideo]);

      await videoManager.loadUserVideos('user_1');
      expect(videoManager.userVideos, hasLength(2));

      // ACT: Update only video_1
      final updatedData = {
        'videoName': 'Updated Video',
        'seriesId': 'series_xyz',
        'episodes': [
          {'id': 'video_1', 'videoName': 'Updated Video'},
        ],
      };

      videoManager.updateVideoInList('video_1', updatedData);

      // ASSERT: Find by ID (sort may reorder)
      final updated = videoManager.userVideos.firstWhere((v) => v.id == 'video_1');
      final untouched = videoManager.userVideos.firstWhere((v) => v.id == 'video_2');
      expect(updated.seriesId, equals('series_xyz'));
      expect(untouched.seriesId, isNull);
    });

    test('should properly unlink series when seriesId and episodes are set to null', () async {
      final seriesVideo = testVideo.copyWith(
        seriesId: 'series_123',
        episodes: [
          {'id': 'video_1', 'videoName': 'Video 1'},
          {'id': 'video_2', 'videoName': 'Video 2'},
        ],
      );

      when(() => mockVideoService.getUserVideos(
            any(),
            forceRefresh: any(named: 'forceRefresh'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [seriesVideo]);

      await videoManager.loadUserVideos('user_1');
      expect(videoManager.userVideos.first.isMultiEpisodeSeries, isTrue);

      // ACT: Unlink series via updateVideoInList with nulls
      videoManager.updateVideoInList('video_1', {
        'seriesId': null,
        'episodes': null,
      });

      // ASSERT: Video should be unlinked and no longer a multi-episode series
      final unlinked = videoManager.userVideos.first;
      expect(unlinked.seriesId, isNull);
      expect(unlinked.episodes, isNull);
      expect(unlinked.isMultiEpisodeSeries, isFalse);
    });

    test('should prune episodes from remaining video and dissolve series when sibling video is deleted', () async {
      final ep1 = testVideo.copyWith(
        id: 'ep_1',
        seriesId: 'series_abc',
        episodes: [
          {'id': 'ep_1', 'videoName': 'Episode 1'},
          {'id': 'ep_2', 'videoName': 'Episode 2'},
        ],
      );
      final ep2 = testVideo.copyWith(
        id: 'ep_2',
        seriesId: 'series_abc',
        episodes: [
          {'id': 'ep_1', 'videoName': 'Episode 1'},
          {'id': 'ep_2', 'videoName': 'Episode 2'},
        ],
      );

      when(() => mockVideoService.getUserVideos(
            any(),
            forceRefresh: any(named: 'forceRefresh'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [ep1, ep2]);
      when(() => mockVideoService.deleteVideos(any())).thenAnswer((_) async => 1);
      when(() => mockCacheManager.invalidateVideoCache()).thenAnswer((_) async {});

      await videoManager.loadUserVideos('user_1');
      expect(videoManager.userVideos, hasLength(2));

      // ACT: Delete ep_2
      await videoManager.deleteSingleVideo('ep_2');

      // ASSERT: ep_1 remains, its episodes array is pruned, and since only 1 remained, series is dissolved
      expect(videoManager.userVideos, hasLength(1));
      final surviving = videoManager.userVideos.first;
      expect(surviving.id, equals('ep_1'));
      expect(surviving.seriesId, isNull);
      expect(surviving.episodes, isNull);
      expect(surviving.isMultiEpisodeSeries, isFalse);
    });
  });
}
