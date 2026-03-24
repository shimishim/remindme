import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/models/reminder.dart';
import 'package:reminder_app/providers/reminder_providers.dart';

class ReminderCard extends ConsumerWidget {
  final Reminder reminder;
  final bool isCompleted;

  const ReminderCard({
    Key? key,
    required this.reminder,
    this.isCompleted = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: isCompleted ? 0 : 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isCompleted
              ? Border.all(color: Colors.grey[300]!)
              : Border.all(
                  color: _getStatusColor().withOpacity(0.3),
                  width: 2,
                ),
          color: isCompleted ? Colors.grey[50] : Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted ? Colors.green : _getStatusColor(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                            color:
                                isCompleted ? Colors.grey[600] : Colors.black,
                          ),
                    ),
                  ),
                  if (reminder.escalationLevel > 0 && !isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'L${reminder.escalationLevel}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (reminder.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 8),
                  child: Text(
                    reminder.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      reminder.formatScheduledTime(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getPersonalityColor().withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getPersonalityEmoji(reminder.personality),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (reminder.allowVoice) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.call,
                        size: 14,
                        color: Colors.blue[600],
                      ),
                    ],
                  ],
                ),
              ),
              if (!isCompleted)
                SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleComplete(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                          child: const Text('עשיתי ✓',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleSnooze(context, ref),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.orange),
                          ),
                          child: const Text('דחה 10 דקות',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: OutlinedButton(
                          onPressed: () => _handleDelete(context, ref),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: const Icon(Icons.delete_outline,
                              size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (reminder.status) {
      case 'pending':
        return reminder.isOverdue ? Colors.red : Colors.blue;
      case 'snoozed':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPersonalityColor() {
    switch (reminder.personality) {
      case 'sarcastic':
        return Colors.purple;
      case 'coach':
        return Colors.blue;
      case 'friend':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPersonalityEmoji(String personality) {
    switch (personality) {
      case 'sarcastic':
        return '😏';
      case 'coach':
        return '💪';
      case 'friend':
        return '😊';
      default:
        return '🔔';
    }
  }

  Future<void> _handleComplete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(completeReminderProvider(reminder.id).future);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('תזכורת הושלמה ✓')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה, נסה שוב')),
      );
    }
  }

  Future<void> _handleSnooze(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(
        snoozeReminderProvider(
          SnoozeReminderParams(
            reminderId: reminder.id,
            minutes: 10,
          ),
        ).future,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הודחה ל־10 דקות')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שגיאה בדחייה')),
      );
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחק תזכורת?'),
        content: const Text('לא ניתן להחזיר זאת.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(deleteReminderProvider(reminder.id).future);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('תזכורת נמחקה')),
                );
              } catch (_) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('שגיאה במחיקה')),
                );
              }
            },
            child: const Text('מחק', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
