import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/config/gemini_config.dart';

/// Applied AI Feature: a pet-wellness chat assistant.
///
/// Grounds every response in the user's most recent Firestore health log
/// (calories, weight, rest time) so the AI is actually reasoning about the
/// user's real data — matching the Part 1 proposal ("AI chatbot that
/// analyses the user's inputted data about their pet").
class AiAssistantScreen extends ConsumerStatefulWidget {
  static const String routeName = '/ai-assistant';
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage(this.text, this.isUser);
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  late final GenerativeModel _model = GenerativeModel(
    model: GeminiConfig.modelName,
    apiKey: GeminiConfig.apiKey,
  );

  // Fetched ONCE when the screen opens, then reused for every message —
  // avoids re-querying Firestore on every single chat turn.
  String _petContextText = 'Loading pet data...';
  bool _isLoadingContext = true;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      "Hi! I'm your PawPulse Assistant. Ask me anything about your pet's "
      "diet, weight trend, or activity — I'll factor in your logged data.",
      false,
    ));
    _loadPetContext();
  }

  Future<void> _loadPetContext() async {
    final contextText = await ref.read(firebaseServiceProvider).getHealthLogsContextText();
    if (mounted) {
      setState(() {
        _petContextText = contextText;
        _isLoadingContext = false;
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text, true));
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      // Uses the context fetched once in initState — no Firestore query
      // happens here, matching the lab's fetch-once pattern.
      final prompt = '''
You are a friendly, cautious pet-wellness assistant inside the PawPulse app.
Here is the user's recently logged pet health data (most recent first):
$_petContextText

Answer the user's question below. Keep responses short (3-5 sentences),
practical, and always recommend a vet visit for anything that sounds
medically serious. Do not diagnose medical conditions.

User's question: $text
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      final reply = response.text ?? "Sorry, I couldn't generate a response. Please try again.";

      setState(() => _messages.add(_ChatMessage(reply, false)));
    } catch (e) {
      setState(() => _messages.add(_ChatMessage('Error reaching the AI service: $e', false)));
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PawPulse AI Assistant'),
        actions: [
          IconButton(
            tooltip: 'Refresh pet data',
            icon: _isLoadingContext
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _isLoadingContext ? null : _loadPetContext,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isSending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your pet...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: const Icon(Icons.send),
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