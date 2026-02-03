import 'package:flutter/material.dart';

class BeliefRewiringPage extends StatefulWidget {
  const BeliefRewiringPage({super.key});

  @override
  State<BeliefRewiringPage> createState() => _BeliefRewiringPageState();
}

class _BeliefRewiringPageState extends State<BeliefRewiringPage> {
  final int _currentDay = 5;
  final int _totalDays = 21;
  bool _isPlaying = false;
  double _progress = 0.0;

  final List<_RewiringSession> _sessions = [
    _RewiringSession(
      day: 1,
      title: 'Understanding Your Beliefs',
      description: 'Identify limiting beliefs that hold you back',
      duration: '10 min',
      isCompleted: true,
      category: 'Foundation',
    ),
    _RewiringSession(
      day: 2,
      title: 'The Power of Identity',
      description: 'Who you believe you are shapes your results',
      duration: '10 min',
      isCompleted: true,
      category: 'Foundation',
    ),
    _RewiringSession(
      day: 3,
      title: 'Reframing Rejection',
      description: 'Turn rejection into redirection',
      duration: '10 min',
      isCompleted: true,
      category: 'Mental Reframing',
    ),
    _RewiringSession(
      day: 4,
      title: 'Confidence Anchoring',
      description: 'Build unshakeable confidence triggers',
      duration: '10 min',
      isCompleted: true,
      category: 'Mental Reframing',
    ),
    _RewiringSession(
      day: 5,
      title: 'Overcoming Fear of Rejection',
      description: 'Transform fear into fuel for action',
      duration: '10 min',
      isCompleted: false,
      category: 'Mental Reframing',
      isToday: true,
    ),
    _RewiringSession(
      day: 6,
      title: 'The Abundance Mindset',
      description: 'There are infinite opportunities',
      duration: '10 min',
      isCompleted: false,
      category: 'Visualization',
    ),
    _RewiringSession(
      day: 7,
      title: 'Visualizing Success',
      description: 'See your success before it happens',
      duration: '10 min',
      isCompleted: false,
      category: 'Visualization',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFFf093fb),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Day $_currentDay of $_totalDays',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Belief Rewiring',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '21-Day Transformation Journey',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _currentDay / _totalDays,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${((_currentDay / _totalDays) * 100).toInt()}% Complete',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Today's Session
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTodaysSession(),
            ),
          ),

          // Session List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Sessions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(onPressed: () {}, child: const Text('View All')),
                ],
              ),
            ),
          ),

          // Session List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final session = _sessions[index];
                return _buildSessionCard(session);
              }, childCount: _sessions.length),
            ),
          ),

          // Bottom Padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildTodaysSession() {
    final todaySession = _sessions.firstWhere(
      (s) => s.isToday,
      orElse: () => _sessions.first,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFf093fb).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "TODAY'S SESSION",
                  style: TextStyle(
                    color: Color(0xFFf093fb),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                todaySession.duration,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            todaySession.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            todaySession.description,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Audio Player
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Progress
                Row(
                  children: [
                    Text(
                      '${(_progress * 10).toInt()}:00',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Expanded(
                      child: Slider(
                        value: _progress,
                        onChanged: (value) {
                          setState(() => _progress = value);
                        },
                        activeColor: const Color(0xFFf093fb),
                        inactiveColor: Colors.grey[300],
                      ),
                    ),
                    Text(
                      '10:00',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.replay_10),
                      iconSize: 32,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isPlaying = !_isPlaying);
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.forward_10),
                      iconSize: 32,
                      color: Colors.grey[700],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mark Complete Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Mark as Complete',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf093fb),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(_RewiringSession session) {
    final isLocked = session.day > _currentDay && !session.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: session.isCompleted
                ? const Color(0xFF4ECDC4)
                : session.isToday
                ? const Color(0xFFf093fb)
                : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: session.isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : isLocked
                ? const Icon(Icons.lock, color: Colors.white, size: 20)
                : Text(
                    '${session.day}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isLocked ? Colors.grey[400] : Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.description,
              style: TextStyle(
                color: isLocked ? Colors.grey[300] : Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf093fb).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: isLocked
                          ? Colors.grey[400]
                          : const Color(0xFFf093fb),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: isLocked ? Colors.grey[300] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  session.duration,
                  style: TextStyle(
                    fontSize: 12,
                    color: isLocked ? Colors.grey[300] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: session.isToday
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : session.isCompleted
            ? const Icon(Icons.check_circle, color: Color(0xFF4ECDC4))
            : isLocked
            ? null
            : Icon(Icons.play_circle_outline, color: Colors.grey[400]),
      ),
    );
  }
}

class _RewiringSession {
  final int day;
  final String title;
  final String description;
  final String duration;
  final bool isCompleted;
  final String category;
  final bool isToday;

  _RewiringSession({
    required this.day,
    required this.title,
    required this.description,
    required this.duration,
    required this.isCompleted,
    required this.category,
    this.isToday = false,
  });
}
