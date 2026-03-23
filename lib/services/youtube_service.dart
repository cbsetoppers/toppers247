import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class VideoQuality {
  final String label;    // e.g. "720p", "480p", "Live"
  final String url;      // direct playable stream URL
  final int bitrate;     // bps, used for sorting

  const VideoQuality({
    required this.label,
    required this.url,
    required this.bitrate,
  });
}

class YTVideoInfo {
  final String title;
  final String author;
  final bool isLive;
  final List<VideoQuality> qualities; // sorted best → worst
  final Duration? duration;           // null for live

  const YTVideoInfo({
    required this.title,
    required this.author,
    required this.isLive,
    required this.qualities,
    this.duration,
  });
}

class YoutubeService {
  static final _yt = YoutubeExplode();

  /// Extracts video ID from all YouTube URL formats:
  ///   youtu.be/ID
  ///   youtube.com/watch?v=ID
  ///   youtube.com/live/ID
  ///   youtube.com/shorts/ID
  ///   youtube.com/embed/ID
  static String? extractVideoId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    
    // Short URL: youtu.be/ID
    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
    }
    
    // Standard: watch?v=ID
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    
    // Path-based: /live/ID, /shorts/ID, /embed/ID
    if (uri.pathSegments.length >= 2 &&
        ['live', 'shorts', 'embed'].contains(uri.pathSegments[0])) {
      return uri.pathSegments[1];
    }
    
    // Fallback regex for common ID formats if parsing fails or isn't perfect
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    
    return null;
  }

  /// Fetches video info and all available stream qualities.
  static Future<YTVideoInfo> getInfo(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      throw Exception(
          'Could not extract video ID from URL.\n'
          'Supported formats: youtu.be/ID, youtube.com/watch?v=ID, '
          'youtube.com/live/ID');
    }

    final video = await _yt.videos.get(videoId);
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final isLive = video.isLive;
    final qualities = <VideoQuality>[];

    if (isLive) {
      // Live stream — use HLS manifest URL
      final hls = manifest.hls.firstOrNull;
      if (hls == null) throw Exception('No live stream URL found');
      qualities.add(VideoQuality(
        label: 'Live',
        url: hls.url.toString(),
        bitrate: 0,
      ));
    } else {
      // Muxed streams: directly playable (video+audio combined)
      // YouTube typically provides 360p and 720p as muxed
      final muxed = manifest.muxed.sortByVideoQuality();
      final seen = <String>{};
      for (final s in muxed) {
        final label = '${s.videoResolution.height}p';
        if (seen.add(label)) {
          qualities.add(VideoQuality(
            label: label,
            url: s.url.toString(),
            bitrate: s.bitrate.bitsPerSecond.toInt(),
          ));
        }
      }
      // Best quality first
      qualities.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    }

    if (qualities.isEmpty) {
      throw Exception('No playable streams found for this video.');
    }

    return YTVideoInfo(
      title: video.title,
      author: video.author,
      isLive: isLive,
      qualities: qualities,
      duration: isLive ? null : video.duration,
    );
  }

  static void dispose() => _yt.close();
}
