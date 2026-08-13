import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/audio_providers.dart';
import '../../../models/sound_track.dart';
import '../../widgets/glass_panel.dart';

class SoundscapesScreen extends ConsumerWidget {
  const SoundscapesScreen({super.key});

  static const _icons = {
    'white_noise': Icons.blur_on,
    'brown_noise': Icons.waves,
    'rainfall': Icons.grain,
    'ambient_drift': Icons.nightlight_round,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(soundTrackCatalogProvider);
    final audio = ref.watch(audioServiceProvider);
    final playerStateAsync = ref.watch(playerStateProvider);
    final currentTrack = audio.currentTrack;
    final isPlaying = playerStateAsync.value?.playing ?? false;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        children: [
          const Text('Soundscapes',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Plays in the background — lock your screen and it keeps going.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          ...tracks.map((track) {
            final isCurrent = currentTrack?.id == track.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TrackTile(
                track: track,
                icon: _icons[track.id] ?? Icons.music_note,
                isCurrent: isCurrent,
                isPlaying: isCurrent && isPlaying,
                onTap: () async {
                  if (isCurrent && isPlaying) {
                    await audio.pause();
                  } else if (isCurrent && !isPlaying) {
                    await audio.play(track);
                  } else {
                    await audio.play(track);
                  }
                },
              ),
            );
          }),
          if (currentTrack != null) ...[
            const SizedBox(height: 12),
            _SleepTimerRow(audio: audio),
          ],
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.icon,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final SoundTrack track;
  final IconData icon;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.all(16),
        borderColor: isCurrent ? AppColors.accentPrimary.withOpacity(0.5) : null,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGlow,
                boxShadow: isCurrent
                    ? AppTheme.glow(AppColors.accentPrimary, blur: 16, opacity: 0.4)
                    : null,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(track.category,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(
              isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: isCurrent ? AppColors.accentPrimary : AppColors.textMuted,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepTimerRow extends StatefulWidget {
  const _SleepTimerRow({required this.audio});
  final dynamic audio; // AudioService

  @override
  State<_SleepTimerRow> createState() => _SleepTimerRowState();
}

class _SleepTimerRowState extends State<_SleepTimerRow> {
  static const _options = [15, 30, 45, 60];
  int? _activeMinutes;
  VoidCallback? _cancelTimer;

  @override
  void dispose() {
    _cancelTimer?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.accentSecondary, size: 18),
              const SizedBox(width: 8),
              const Text('Sleep timer',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
              if (_activeMinutes != null) ...[
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _cancelTimer?.call();
                    setState(() => _activeMinutes = null);
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: _options.map((minutes) {
              final selected = _activeMinutes == minutes;
              return ChoiceChip(
                label: Text('${minutes}m'),
                selected: selected,
                selectedColor: AppColors.accentPrimary,
                backgroundColor: AppColors.glassFill,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                ),
                onSelected: (_) {
                  _cancelTimer?.call();
                  _cancelTimer = widget.audio.setSleepTimer(Duration(minutes: minutes));
                  setState(() => _activeMinutes = minutes);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
