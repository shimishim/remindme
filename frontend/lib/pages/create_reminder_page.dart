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
  bool _isSpeaking = false;
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
      appBar: AppBar(
        title: const Text('תזכורת חדשה'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Input field
          Text(
            'מה אתה צריך להיזכר?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'דוגמה: "להתקשר לחזי הערב ב־8"',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
              suffixIcon: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.grey[600],
                  size: 28,
                ),
                tooltip: 'הקלט דיבור',
                onPressed: _isListening ? _stopListening : _startListening,
              ),
            ),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.graphic_eq, color: Colors.red[400], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'מאזין...',
                    style: TextStyle(
                        color: Colors.red[400], fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          if (_speechError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_speechError, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 24),

          // Personality selection
          Text(
            'בחר סגנון תזכורת',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PersonalityChip(
                personality: 'sarcastic',
                emoji: '😏',
                label: 'צינוי',
                isSelected: _selectedPersonality == 'sarcastic',
                onSelected: () =>
                    setState(() => _selectedPersonality = 'sarcastic'),
              ),
              const SizedBox(width: 8),
              _PersonalityChip(
                personality: 'coach',
                emoji: '💪',
                label: 'מאמן',
                isSelected: _selectedPersonality == 'coach',
                onSelected: () =>
                    setState(() => _selectedPersonality = 'coach'),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 24),

          // Voice call option
          Card(
            child: CheckboxListTile(
              title: const Text('אפילו עם שיחת טלפון?'),
              subtitle: const Text('אם לא תגיב, יתקשר אלייך'),
              value: _allowVoice,
              onChanged: (value) {
                setState(() => _allowVoice = value ?? false);
              },
              secondary: const Icon(Icons.call),
            ),
          ),
          const SizedBox(height: 24),

          // Description
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    const Text(
                      'טיפס',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'אתה יכול לפשט לשפה טבעית:\n'
                  '• "להתקשר לחזי הערב"\n'
                  '• "דיון עם בוס מחר בשעה 2"\n'
                  '• "קנות מכולת בעוד שעה"',
                  style: TextStyle(fontSize: 12),
                ),
              ],
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
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 4,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSpeaking() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
      return;
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(_textController.text, language: 'he-IL');
    setState(() => _isSpeaking = false);
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

  void _handleCreate() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('אנא כתוב תזכורת')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(
        createReminderProvider(
          CreateReminderParams(
            text: _textController.text,
            personality: _selectedPersonality,
            allowVoice: _allowVoice,
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
    return Expanded(
      child: GestureDetector(
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[100] : Colors.grey[100],
            border: Border.all(
              color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
