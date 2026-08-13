import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/providers.dart';
import '../../../models/user_profile.dart';
import '../../widgets/glass_panel.dart';

/// Collects the baseline data that becomes Kitty AI's permanent context
/// window (see UserProfile.toAiContextString). Writes once, on submit —
/// no partial/fake saves along the way.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  DateTime? _birthdate;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  double _sleepGoalHours = 8;
  int _stepGoal = 8000;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  bool get _canContinueFromStep0 => _birthdate != null;
  bool get _canContinueFromStep1 =>
      double.tryParse(_weightCtrl.text) != null && double.tryParse(_heightCtrl.text) != null;

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final firestore = ref.read(firestoreServiceProvider);
      final existing = await firestore.getProfile(user.uid) ??
          UserProfile.newForUid(user.uid, isGuest: user.isAnonymous, displayName: user.displayName);

      final updated = existing.copyWith(
        birthdate: _birthdate,
        weightKg: double.parse(_weightCtrl.text),
        heightCm: double.parse(_heightCtrl.text),
        sleepGoalMinutes: (_sleepGoalHours * 60).round(),
        stepGoal: _stepGoal,
        onboardingComplete: true,
      );

      await firestore.saveOnboardingData(updated);
      // Router redirects to /home automatically once userProfileProvider
      // reflects onboardingComplete == true.
    } catch (e) {
      setState(() => _error = 'Could not save your profile. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressDots(page: _page, count: 3),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _BirthdateStep(
                    selected: _birthdate,
                    onSelected: (d) => setState(() => _birthdate = d),
                  ),
                  _WeightHeightStep(weightCtrl: _weightCtrl, heightCtrl: _heightCtrl),
                  _GoalsStep(
                    sleepGoalHours: _sleepGoalHours,
                    stepGoal: _stepGoal,
                    onSleepGoalChanged: (v) => setState(() => _sleepGoalHours = v),
                    onStepGoalChanged: (v) => setState(() => _stepGoal = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving || !_stepIsValid() ? null : _next,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_page == 2 ? 'Finish' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _stepIsValid() {
    switch (_page) {
      case 0:
        return _canContinueFromStep0;
      case 1:
        return _canContinueFromStep1;
      default:
        return true;
    }
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.page, required this.count});
  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: List.generate(count, (i) {
          final active = i <= page;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 8),
              height: 4,
              decoration: BoxDecoration(
                color: active ? AppColors.accentPrimary : AppColors.glassFill,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BirthdateStep extends StatelessWidget {
  const _BirthdateStep({required this.selected, required this.onSelected});
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('When were you born?',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Kitty AI uses this to tailor sleep-cycle guidance to your age group.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 28),
          GlassPanel(
            child: InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selected ?? DateTime(now.year - 25),
                  firstDate: DateTime(now.year - 100),
                  lastDate: DateTime(now.year - 5),
                );
                if (picked != null) onSelected(picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: AppColors.accentSecondary),
                  const SizedBox(width: 12),
                  Text(
                    selected == null
                        ? 'Select your birthdate'
                        : '${selected!.month}/${selected!.day}/${selected!.year}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightHeightStep extends StatelessWidget {
  const _WeightHeightStep({required this.weightCtrl, required this.heightCtrl});
  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A bit about your body',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Used for calorie and recovery calculations. You can change this anytime.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 28),
          TextField(
            controller: weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: heightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Height (cm)'),
          ),
        ],
      ),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({
    required this.sleepGoalHours,
    required this.stepGoal,
    required this.onSleepGoalChanged,
    required this.onStepGoalChanged,
  });

  final double sleepGoalHours;
  final int stepGoal;
  final ValueChanged<double> onSleepGoalChanged;
  final ValueChanged<int> onStepGoalChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set your baseline goals',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          Text('Sleep goal: ${sleepGoalHours.toStringAsFixed(1)} hrs / night',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          Slider(
            value: sleepGoalHours,
            min: 5,
            max: 10,
            divisions: 10,
            activeColor: AppColors.accentPrimary,
            onChanged: onSleepGoalChanged,
          ),
          const SizedBox(height: 12),
          Text('Daily step goal: $stepGoal',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          Slider(
            value: stepGoal.toDouble(),
            min: 3000,
            max: 15000,
            divisions: 12,
            activeColor: AppColors.accentSecondary,
            onChanged: (v) => onStepGoalChanged(v.round()),
          ),
        ],
      ),
    );
  }
}
