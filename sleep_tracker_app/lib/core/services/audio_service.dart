import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

import '../../models/sound_track.dart';

/// Real background-audio playback via `just_audio` + `just_audio_background`.
/// `JustAudioBackground.init(...)` must run once in `main()` *before*
/// `runApp` — that registers the lock-screen / notification media controls.
/// This service just drives the player and attaches a real `MediaItem` tag
/// per track so the lock screen shows actual title/art, not a generic
/// "Unknown track" placeholder.
///
/// Loops indefinitely by default, which is the expected behavior for white
/// noise / rain / ambient tracks used as sleep aids.
class AudioService {
  AudioService() : _logger = Logger() {
    _init();
  }

  final Logger _logger;
  final AudioPlayer player = AudioPlayer();
  SoundTrack? _current;

  SoundTrack? get currentTrack => _current;
  Stream<PlayerState> get playerStateStream => player.playerStateStream;
  bool get isPlaying => player.playing;

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await player.setLoopMode(LoopMode.one);
    } catch (e) {
      _logger.e('Audio session configuration failed', error: e);
    }
  }

  /// Loads and plays [track]. Re-uses the current source if the same track
  /// is already loaded (e.g. resuming after pause) instead of reloading.
  Future<void> play(SoundTrack track) async {
    try {
      if (_current?.id != track.id) {
        _current = track;
        await player.setAudioSource(
          AudioSource.uri(
            Uri.parse(track.streamUrl),
            tag: MediaItem(
              id: track.id,
              album: 'Kitty Sleep',
              title: track.title,
              artUri: Uri.tryParse(track.artUrl),
            ),
          ),
        );
      }
      await player.play();
    } catch (e) {
      _logger.e('Failed to play track ${track.id}', error: e);
      rethrow;
    }
  }

  Future<void> pause() => player.pause();

  Future<void> stop() async {
    await player.stop();
    _current = null;
  }

  /// Stops playback after [duration] — the standard "sleep timer" feature.
  /// Returns a cancel function so the UI can abort the timer if the user
  /// changes their mind.
  VoidCallbackHandle setSleepTimer(Duration duration) {
    var cancelled = false;
    Future.delayed(duration, () {
      if (!cancelled && player.playing) player.pause();
    });
    return () => cancelled = true;
  }

  void dispose() {
    player.dispose();
  }
}

typedef VoidCallbackHandle = void Function();
