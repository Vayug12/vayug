import 'package:vayug/shared/utils/app_logger.dart';

class UrlValidationResult {
  final bool isValid;
  final String? errorKey;

  const UrlValidationResult._(this.isValid, this.errorKey);

  static const valid = UrlValidationResult._(true, null);
  static const empty = UrlValidationResult._(false, 'url_empty');
  static const noScheme = UrlValidationResult._(false, 'url_no_scheme');
  static const invalidScheme = UrlValidationResult._(false, 'url_invalid_scheme');
  static const noDomain = UrlValidationResult._(false, 'url_no_domain');
  static const noTld = UrlValidationResult._(false, 'url_no_tld');
  static const invalidFormat = UrlValidationResult._(false, 'url_invalid_format');
  static const localhost = UrlValidationResult._(false, 'url_localhost');

  String get userMessage {
    switch (errorKey) {
      case 'url_empty':
        return 'Please enter a URL';
      case 'url_no_scheme':
        return 'URL must start with https://';
      case 'url_invalid_scheme':
        return 'Only https:// links are allowed';
      case 'url_no_domain':
        return 'URL must have a valid domain (e.g. example.com)';
      case 'url_no_tld':
        return 'Domain must end with a valid extension (e.g. .com, .in, .org)';
      case 'url_localhost':
        return 'Localhost URLs are not allowed';
      case 'url_invalid_format':
        return 'This URL format looks invalid';
      default:
        return 'Invalid URL';
    }
  }
}

class UrlUtils {
  static const int _maxVideoSlugLength = 80;

  /// Validates a URL format for creator links.
  /// Returns [UrlValidationResult] with validity and error key.
  static UrlValidationResult validateUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return UrlValidationResult.empty;

    String url = trimmed;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    if (!url.startsWith('https://')) {
      return UrlValidationResult.invalidScheme;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return UrlValidationResult.noDomain;
    }

    final host = uri.host.toLowerCase();

    if (host == 'localhost' || host.startsWith('127.') || host.startsWith('0.')) {
      return UrlValidationResult.localhost;
    }

    if (!host.contains('.')) {
      return UrlValidationResult.noTld;
    }

    final parts = host.split('.');
    final tld = parts.last;
    if (tld.length < 2 || !RegExp(r'^[a-z]+$').hasMatch(tld)) {
      return UrlValidationResult.noTld;
    }

    if (parts.length < 2 || parts.any((p) => p.isEmpty)) {
      return UrlValidationResult.invalidFormat;
    }

    return UrlValidationResult.valid;
  }

  static String slugifyVideoTitle(String title) {
    var slug = title
        .trim()
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    if (slug.length > _maxVideoSlugLength) {
      slug = slug.substring(0, _maxVideoSlugLength).replaceAll(
            RegExp(r'-+$'),
            '',
          );
    }

    return slug.isEmpty ? 'video' : slug;
  }

  static String buildVideoShareUrl(
    String videoId,
    String title, {
    Map<String, String>? queryParameters,
  }) {
    return Uri.https(
      'snehayog.site',
      '/video/$videoId/${slugifyVideoTitle(title)}',
      queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    ).toString();
  }

  /// Enriches a URL with UTM parameters for attribution tracking.
  /// 
  /// [source] defaults to 'vayug'
  /// [medium] e.g., 'app_ad', 'profile', 'internal_link'
  /// [campaign] e.g., 'vayug_ads', 'creator_visit'
  /// [content] optional specific identifier (e.g., ad ID)
  static String enrichUrl(
    String url, {
    String source = 'vayug',
    String? medium,
    String? campaign,
    String? content,
  }) {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return trimmedUrl;

    try {
      // Ensure the URL has a scheme before parsing
      final effectiveUrl = trimmedUrl.startsWith('http') 
          ? trimmedUrl 
          : 'https://$trimmedUrl';
          
      final uri = Uri.parse(effectiveUrl);
      final queryParams = Map<String, String>.from(uri.queryParameters);

      // Add UTM parameters if they aren't already present
      if (!queryParams.containsKey('utm_source')) {
        queryParams['utm_source'] = source;
      }
      if (medium != null && !queryParams.containsKey('utm_medium')) {
        queryParams['utm_medium'] = medium;
      }
      if (campaign != null && !queryParams.containsKey('utm_campaign')) {
        queryParams['utm_campaign'] = campaign;
      }
      if (content != null && !queryParams.containsKey('utm_content')) {
        queryParams['utm_content'] = content;
      }

      final enrichedUri = uri.replace(queryParameters: queryParams);
      final finalUrl = enrichedUri.toString();
      
      AppLogger.log('🔗 UrlUtils: Enriched URL: $finalUrl');
      return finalUrl;
    } catch (e) {
      AppLogger.log('⚠️ UrlUtils: Error enriching URL ($url): $e');
      return trimmedUrl; // Return original if parsing fails
    }
  }

  /// Formats a URL into a clean, shortened domain string for safe display on buttons.
  /// Example: 'https://chat.whatsapp.com/...' -> 'chat.whatsapp'
  /// Example: 'https://www.youtube.com/watch?v=...' -> 'youtube'
  /// Example: 'https://play.google.com/store/...' -> 'play.google'
  static String formatShortDomain(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';

    try {
      var domain = trimmed
          .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
          .split('/')
          .first
          .split('?')
          .first
          .split('#')
          .first
          .replaceFirst(RegExp(r'\.com$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\.in$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\.org$', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\.net$', caseSensitive: false), '')
          .trim();

      return domain.isNotEmpty ? domain : trimmed;
    } catch (_) {
      return trimmed;
    }
  }
}
