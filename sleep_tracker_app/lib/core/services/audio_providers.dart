import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/sound_track.dart';
import 'audio_service.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioServiceProvider).playerStateStream;
});

/// Track catalog. `streamUrl` values here are placeholders — replace with
/// URLs to your own licensed, hosted audio files (Firebase Storage /
/// S3 / CDN). The playback engine itself is fully wired and works with any
/// valid direct audio URL; see README "Soundscape audio files".
final soundTrackCatalogProvider = Provider<List<SoundTrack>>((ref) {
  return const [
    SoundTrack(
      id: 'white_noise',
      title: 'White Noise',
      category: 'Noise',
      streamUrl: 'REPLACE_WITH_YOUR_HOSTED_AUDIO_URL/white-noise.mp3',
      artUrl: 'REPLACE_WITH_YOUR_HOSTED_ART_URL/white-noise.png',
    ),
    SoundTrack(
      id: 'brown_noise',
      title: 'Brown Noise',
      category: 'Noise',
      streamUrl: 'REPLACE_WITH_YOUR_HOSTED_AUDIO_URL/brown-noise.mp3',
      artUrl: 'REPLACE_WITH_YOUR_HOSTED_ART_URL/brown-noise.png',
    ),
    SoundTrack(
      id: 'rainfall',
      title: 'Rainfall',
      category: 'Nature',
      streamUrl: 'REPLACE_WITH_YOUR_HOSTED_AUDIO_URL/rainfall.mp3',
      artUrl: 'REPLACE_WITH_YOUR_HOSTED_ART_URL/rainfall.png',
    ),
    SoundTrack(
      id: 'ambient_drift',
      title: 'Ambient Drift',
      category: 'Ambient',
      streamUrl: 'REPLACE_WITH_YOUR_HOSTED_AUDIO_URL/ambient-drift.mp3',
      artUrl: 'REPLACE_WITH_YOUR_HOSTED_ART_URL/ambient-drift.png',
    ),
  ];
});
