import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/services/chat_repository.dart';
import '../../../core/services/health_providers.dart';
import '../../../models/chat_message.dart';
import '../../widgets/glass_panel.dart';

final aiServiceProvider = Provider<GeminiAiService>((ref) => GeminiAiService());
final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchMessages(uid);
});

class KittyAiScreen extends ConsumerStatefulWidget {
  const KittyAiScreen({super.key});

  @override
  ConsumerState<KittyAiScreen> createState() => _KittyAiScreenState();
}

class _KittyAiScreenState extends ConsumerState<KittyAiScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _inputCtrl.clear();
    setState(() {
      _sending = true;
      _error = null;
    });

    final chatRepo = ref.read(chatRepositoryProvider);
    final ai = ref.read(aiServiceProvider);
    final profile = ref.read(userProfileProvider).value;
    final health = ref.read(todayHealthSnapshotProvider).value;

    try {
      final userMessage = ChatMessage(
        id: '',
        role: ChatRole.user,
        text: text,
        createdAt: DateTime.now(),
      );
      await chatRepo.addMessage(uid, userMessage);

      final history = await chatRepo.recentHistory(uid);

      final contextBlock = StringBuffer();
      if (profile != null) contextBlock.writeln(profile.toAiContextString());
      if (health != null && health.hasSleepData) {
        contextBlock.writeln('Today so far:');
        contextBlock.writeln('- Total sleep: ${health.totalSleepDuration.inMinutes} minutes');
        if (health.steps != null) contextBlock.writeln('- Steps: ${health.steps}');
        if (health.activeCaloriesKcal != null) {
          contextBlock.writeln('- Active calories: ${health.activeCaloriesKcal!.round()} kcal');
        }
      }

      final reply = await ai.sendMessage(history: history, userContext: contextBlock.toString());

      await chatRepo.addMessage(
        uid,
        ChatMessage(id: '', role: ChatRole.assistant, text: reply, createdAt: DateTime.now()),
      );

      _scrollToBottom();
    } on KittyAiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider);
    final isConfigured = ref.read(aiServiceProvider).isConfigured;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGlow,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Kitty AI',
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            if (!isConfigured)
              GlassPanel(
                padding: const EdgeInsets.all(14),
                child: const Text(
                  'Add GEMINI_API_KEY to your .env file to activate Kitty AI (free — no card required at ai.google.dev).',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Ask Kitty anything about your sleep, recovery, or today\'s activity.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _MessageBubble(message: messages[i]),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary)),
                error: (e, _) => Center(
                  child: Text('Could not load chat: $e',
                      style: const TextStyle(color: AppColors.danger)),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            GlassPanel(
              borderRadius: AppRadii.pill,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask Kitty…',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: AppColors.accentPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.primaryGlow : null,
          color: isUser ? null : AppColors.glassFill,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRadii.md),
            topRight: const Radius.circular(AppRadii.md),
            bottomLeft: Radius.circular(isUser ? AppRadii.md : 4),
            bottomRight: Radius.circular(isUser ? 4 : AppRadii.md),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
