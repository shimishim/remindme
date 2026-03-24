import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/pages/create_reminder_page.dart';
import 'package:reminder_app/providers/reminder_providers.dart';
import 'package:reminder_app/services/auth_service.dart';
import 'package:reminder_app/widgets/reminder_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Register FCM token with backend once after login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final api = ref.read(apiServiceProvider);
      registerFcmTokenIfNeeded(api);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final remindersAsync = ref.watch(userRemindersProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('תזכיר לי'),
        elevation: 2,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'יציאה',
            onPressed: () async {
              // Unregister FCM token before signing out
              await ref.read(apiServiceProvider).unregisterFcmToken();
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'אין תזכורות כעת',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'לחץ על (+ להוסיף תזכורת חדשה',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          // Group reminders by status
          final overdueReminders = reminders
              .where((r) => r.status == 'pending' && r.isOverdue)
              .toList()
            ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
          final activeReminders = reminders
              .where((r) => r.status == 'pending' && !r.isOverdue)
              .toList()
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
          final snoozedReminders = reminders
              .where((r) => r.status == 'snoozed')
              .toList()
            ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
          final completedReminders = reminders
              .where((r) => r.status == 'completed')
              .toList()
            ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Overdue reminders (past scheduled time, not completed)
              if (overdueReminders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'לביצוע',
                  count: overdueReminders.length,
                  color: const Color(0xFF1E40AF),
                ),
                ...overdueReminders
                    .map((r) => ReminderCard(reminder: r))
                    .toList(),
                const SizedBox(height: 16),
              ],

              // Active reminders (scheduled for the future)
              if (activeReminders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'פעיל כעת',
                  count: activeReminders.length,
                  color: const Color(0xFF2563EB),
                ),
                ...activeReminders
                    .map((r) => ReminderCard(reminder: r))
                    .toList(),
                const SizedBox(height: 16),
              ],

              // Snoozed reminders
              if (snoozedReminders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'מושהה',
                  count: snoozedReminders.length,
                  color: Colors.orange,
                ),
                ...snoozedReminders
                    .map((r) => ReminderCard(reminder: r))
                    .toList(),
                const SizedBox(height: 16),
              ],

              // Completed reminders
              if (completedReminders.isNotEmpty) ...[
                _SectionHeader(
                  title: 'הושלמו',
                  count: completedReminders.length,
                  color: Colors.green,
                ),
                ...completedReminders
                    .map((r) => ReminderCard(reminder: r, isCompleted: true))
                    .toList(),
              ],
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Color(0xFF60A5FA)),
              const SizedBox(height: 16),
              Text('שגיאה בטעינה: $error'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(userRemindersProvider(userId)),
                child: const Text('נסה שוב'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateReminderPage(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('תזכורת חדשה'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 8,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            color: color,
            margin: const EdgeInsets.only(right: 12),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
