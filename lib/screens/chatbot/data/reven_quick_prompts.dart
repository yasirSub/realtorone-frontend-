/// Pre-built quick prompts shown to the user before they type anything.
/// Each prompt has a canned [reply] that works as a placeholder until the
/// real AI / knowledge-base integration is wired in.
///
/// To add a new category or prompt, simply append to [revenPromptCategories].

class RevenQuickPrompt {
  final String emoji;

  /// Short label shown on the chip button.
  final String label;

  /// Full message that appears as the user's chat bubble when tapped.
  final String message;

  /// Placeholder reply from Reven (replace with AI response later).
  final String reply;

  const RevenQuickPrompt({
    required this.emoji,
    required this.label,
    required this.message,
    required this.reply,
  });
}

class RevenPromptCategory {
  final String title;
  final List<RevenQuickPrompt> prompts;

  const RevenPromptCategory({required this.title, required this.prompts});
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / edit prompts here.  Later, swap [reply] values for real API calls.
// ─────────────────────────────────────────────────────────────────────────────

const List<RevenPromptCategory> revenPromptCategories = [
  RevenPromptCategory(
    title: 'Get started',
    prompts: [
      RevenQuickPrompt(
        emoji: '🤖',
        label: 'What can you do?',
        message: 'What can you do?',
        reply:
            'I can help you navigate your training, track tasks, explain courses, '
            'and answer real estate questions. AI-powered answers and a full '
            'knowledge base are coming soon!',
      ),
      RevenQuickPrompt(
        emoji: '📚',
        label: 'My courses',
        message: 'Show me my enrolled courses',
        reply:
            'Your enrolled programs are in the Courses tab. '
            'Soon I\'ll show your progress and suggest what to study next '
            'right here!',
      ),
      RevenQuickPrompt(
        emoji: '🏆',
        label: 'Leaderboard rank',
        message: 'How do I improve my leaderboard rank?',
        reply:
            'Your rank grows by completing tasks, finishing course modules, '
            'and earning badges. Check the Leaderboard tab to see where you '
            'stand — keep pushing! 💪',
      ),
    ],
  ),

  RevenPromptCategory(
    title: 'Training',
    prompts: [
      RevenQuickPrompt(
        emoji: '📞',
        label: 'Cold calling tips',
        message: 'Give me cold calling tips',
        reply:
            'Great opener + active listening + clear call objective = a '
            'winning cold call. The Cold Calling Master program breaks this '
            'down step by step. Check it out in Courses!',
      ),
      RevenQuickPrompt(
        emoji: '💎',
        label: 'Million Dirham beliefs',
        message: 'Tell me about the Million Dirham Beliefs Program',
        reply:
            'The Million Dirham Beliefs Program rewires your mindset for '
            'elite performance in real estate — covering belief systems, '
            'visualization, and high-performance habits. Find it in your '
            'Courses tab!',
      ),
      RevenQuickPrompt(
        emoji: '📋',
        label: 'Daily tasks',
        message: 'What are my tasks for today?',
        reply:
            'Your daily tasks are on the Dashboard. '
            'Soon I\'ll be able to summarise and prioritise them for you '
            'right here!',
      ),
    ],
  ),

  RevenPromptCategory(
    title: 'Account & badges',
    prompts: [
      RevenQuickPrompt(
        emoji: '🎖️',
        label: 'My badges',
        message: 'Show my earned badges',
        reply:
            'Head to the Badges tab to see every milestone you\'ve unlocked. '
            'Each badge represents real progress — keep going to collect '
            'them all!',
      ),
      RevenQuickPrompt(
        emoji: '⚙️',
        label: 'Update profile',
        message: 'How do I update my profile?',
        reply:
            'Tap your avatar in the app header to open your profile settings. '
            'From there you can update your name, photo, and preferences.',
      ),
    ],
  ),
];
