import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reminder_app/models/reminder.dart';
import 'package:reminder_app/pages/create_reminder_page.dart';
import 'package:reminder_app/providers/reminder_providers.dart';
import 'package:reminder_app/services/auth_service.dart';
import 'package:reminder_app/widgets/reminder_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  void _openCreateReminderPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreateReminderPage(),
      ),
    );
  }

  Future<void> _refreshReminderRuntimeState() async {
    final api = ref.read(apiServiceProvider);
    await registerFcmTokenIfNeeded(api);
    await rescheduleAllPendingReminders(ref);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refreshReminderRuntimeState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshReminderRuntimeState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final remindersAsync = ref.watch(userRemindersProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('התזכורות שלי'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        actions: const [SizedBox(width: 16)],
      ),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return _EmptyHomeState(
              onCreateTap: _openCreateReminderPage,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              const SizedBox(height: 6),
              ..._buildReminderSections(reminders),
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
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFF6B9FEF),
              ),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _HomeCreateButton(
        onPressed: _openCreateReminderPage,
      ),
    );
  }

  List<Widget> _buildReminderSections(List<Reminder> reminders) {
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

    return [
      if (overdueReminders.isNotEmpty) ...[
        _SectionHeader(
          title: 'לביצוע',
          count: overdueReminders.length,
          color: const Color(0xFF4464F6),
        ),
        ...overdueReminders.map((r) => ReminderCard(reminder: r)),
        const SizedBox(height: 16),
      ],
      if (activeReminders.isNotEmpty) ...[
        _SectionHeader(
          title: 'פעיל כעת',
          count: activeReminders.length,
          color: const Color(0xFF4F46E5),
        ),
        ...activeReminders.map((r) => ReminderCard(reminder: r)),
        const SizedBox(height: 16),
      ],
      if (snoozedReminders.isNotEmpty) ...[
        _SectionHeader(
          title: 'מושהה',
          count: snoozedReminders.length,
          color: const Color(0xFFF08A24),
        ),
        ...snoozedReminders.map((r) => ReminderCard(reminder: r)),
        const SizedBox(height: 16),
      ],
      if (completedReminders.isNotEmpty) ...[
        _SectionHeader(
          title: 'הושלמו',
          count: completedReminders.length,
          color: const Color(0xFF2FB369),
        ),
        ...completedReminders
            .map((r) => ReminderCard(reminder: r, isCompleted: true)),
      ],
    ];
  }
}

class _EmptyHomeState extends StatefulWidget {
  final VoidCallback onCreateTap;

  const _EmptyHomeState({
    required this.onCreateTap,
  });

  @override
  State<_EmptyHomeState> createState() => _EmptyHomeStateState();
}

class _EmptyHomeStateState extends State<_EmptyHomeState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.26), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.26, end: -0.26), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.26, end: 0.18), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.18), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.18, end: 0.09), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.09, end: -0.09), weight: 10),
      TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF2FF),
                  shape: BoxShape.circle,
                ),
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value,
                      alignment: const Alignment(0, -0.78),
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    size: 72,
                    color: Color(0xFFA9B4F5),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'הכל שקט כאן...',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  'אין לך תזכורות כרגע. אולי כדאי להוסיף משהו כדי שלא תשכח?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.55,
                        color: const Color(0xFF64748B),
                      ),
                ),
              ),
              const SizedBox(height: 36),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'נסה להגיד',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: const Color(0xFF94A3B8),
                      ),
                ),
              ),
              const SizedBox(height: 12),
              _ExamplePromptChip(
                text: '"תזכיר לי להתקשר לאמא מחר בשעה 7 בערב"',
                onTap: widget.onCreateTap,
              ),
              const SizedBox(height: 12),
              _ExamplePromptChip(
                text: '"לקנות פרחים מחר בערב"',
                onTap: widget.onCreateTap,
              ),
              const SizedBox(height: 12),
              _ExamplePromptChip(
                text: '"תור לרופא עוד שעה"',
                onTap: widget.onCreateTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamplePromptChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ExamplePromptChip({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7ECF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x100F172A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF475569),
                ),
          ),
        ),
      ),
    );
  }
}

class _HomeCreateButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HomeCreateButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF5E56F7), Color(0xFF4B46E5)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x334B46E5),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          extendedPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'תזכורת חדשה',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '($count)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
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
