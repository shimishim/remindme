import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/providers/reminder_providers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:reminder_app/services/tts_service.dart';

import 'package:permission_handler/permission_handler.dart';

class CreateReminderPage extends ConsumerStatefulWidget {
  const CreateReminderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateReminderPage> createState() => _CreateReminderPageState();
}

class _CreateReminderPageState extends ConsumerState<CreateReminderPage> {
  late final TextEditingController _textController;
  String _selectedPersonality = 'sarcastic';
  bool _allowVoice = false;
  bool _isLoading = false;

  late stt.SpeechToText _speech;
  final TtsService _tts = TtsService();
  bool _isListening = false;
  String _speechError = '';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: Text(
          'יצירת תזכורת',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
        ),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        children: [
          // Input field
          Text(
            'מה להזכיר לך?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                minLines: 4,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'לדוגמה: "להתקשר לחזי ב-8 בערב..."',
                  hintStyle: const TextStyle(
                    color: Color(0xFFB8BFCC),
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE6EBF4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE6EBF4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF6B7280),
                          size: 28,
                        ),
                        tooltip: 'הקלט דיבור',
                        onPressed:
                            _isListening ? _stopListening : _startListening,
                      ),
                      if (_isListening) ...[
                        Icon(Icons.graphic_eq,
                            color: const Color(0xFF4F46E5), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'מאזין...',
                          style: const TextStyle(
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_speechError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_speechError,
                      style: const TextStyle(color: Color(0xFF4F46E5))),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Personality selection
          Text(
            'באיזה סגנון?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PersonalityChip(
                personality: 'sarcastic',
                emoji: '😏',
                label: 'ציני',
                isSelected: _selectedPersonality == 'sarcastic',
                onSelected: () =>
                    setState(() => _selectedPersonality = 'sarcastic'),
              ),
              const SizedBox(width: 10),
              _PersonalityChip(
                personality: 'coach',
                emoji: '💪',
                label: 'מאמן',
                isSelected: _selectedPersonality == 'coach',
                onSelected: () =>
                    setState(() => _selectedPersonality = 'coach'),
              ),
              const SizedBox(width: 10),
              _PersonalityChip(
                personality: 'friend',
                emoji: '😊',
                label: 'חבר',
                isSelected: _selectedPersonality == 'friend',
                onSelected: () =>
                    setState(() => _selectedPersonality = 'friend'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Voice call option
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFFE8ECF3)),
            ),
            child: CheckboxListTile(
              title: Text(
                'להתקשר אליי?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
              ),
              subtitle: Text(
                'אם לא אגיב, המערכת תתקשר',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
              ),
              value: _allowVoice,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              activeColor: const Color(0xFF4F46E5),
              checkboxShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() => _allowVoice = value ?? false);
                    },
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.phone_in_talk_outlined,
                  size: 18,
                  color: Color(0xFF4F46E5),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'צור תזכורת',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _startListening() async {
    // בקשת הרשאת מיקרופון
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _isListening = false;
        _speechError = 'לא ניתנה הרשאת מיקרופון';
      });
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() {
          _isListening = false;
          _speechError = error.errorMsg;
        });
      },
    );
    if (available) {
      setState(() {
        _isListening = true;
        _speechError = '';
      });
      _speech.listen(
        localeId: 'he_IL',
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    } else {
      setState(() {
        _isListening = false;
        _speechError = 'Speech recognition unavailable';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _handleCreate() async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    if (_textController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('אנא כתוב תזכורת')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    final allowVoiceForSubmission = _allowVoice;

    try {
      await ref.read(
        createReminderProvider(
          CreateReminderParams(
            text: _textController.text,
            personality: _selectedPersonality,
            allowVoice: allowVoiceForSubmission,
          ),
        ).future,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('התזכורת נוצרה בהצלחה!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('שגיאה: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _PersonalityChip extends StatelessWidget {
  final String personality;
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PersonalityChip({
    required this.personality,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final Color borderColor;
    final Color textColor;

    switch (personality) {
      case 'friend':
        backgroundColor =
            isSelected ? const Color(0xFFEFFAF3) : const Color(0xFFF7FCF8);
        borderColor =
            isSelected ? const Color(0xFFBDE7C7) : const Color(0xFFE3F3E7);
        textColor = const Color(0xFF14804A);
        break;
      case 'coach':
        backgroundColor =
            isSelected ? const Color(0xFFFFF4E8) : const Color(0xFFFFFAF4);
        borderColor =
            isSelected ? const Color(0xFFFFD6A6) : const Color(0xFFFFECD1);
        textColor = const Color(0xFFE47B12);
        break;
      default:
        backgroundColor =
            isSelected ? const Color(0xFFEFF2FF) : const Color(0xFFF7F8FF);
        borderColor =
            isSelected ? const Color(0xFFAFC0FF) : const Color(0xFFE2E8FF);
        textColor = const Color(0xFF4F46E5);
    }

    return Expanded(
      child: GestureDetector(
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
