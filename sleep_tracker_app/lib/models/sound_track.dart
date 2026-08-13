/// A single ambient/noise track. `streamUrl` must point to a real,
/// licensed, hosted audio file (your own CDN/Firebase Storage bucket) —
/// see README "Soundscape audio files" for why no URLs ship by default.
class SoundTrack {
  final String id;
  final String title;
  final String category;
  final String streamUrl;
  final String artUrl;

  const SoundTrack({
    required this.id,
    required this.title,
    required this.category,
    required this.streamUrl,
    required this.artUrl,
  });
}
