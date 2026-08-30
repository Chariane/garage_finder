import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garage Finder'),
        backgroundColor: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.9),
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.wb_sunny
                  : Icons.nightlight_round,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: themeProvider.toggleTheme,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (isDark)
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const NetworkImage(
                    'https://images.unsplash.com/photo-1487754180451-c456f719a9c0?w=1200&h=800&fit=crop',
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                ),
              ),
            )
          else
            Container(
              color: Colors.grey.shade100,
            ),
          Container(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.white.withOpacity(0.85),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween<double>(begin: 0.8, end: 1.0),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(28),
                                child: Icon(
                                  Icons.car_repair,
                                  size: 72,
                                  color: isDark ? Colors.white : Colors.blue.shade700,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Garage Finder',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.blue.shade800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trouvez un garagiste en 2 clics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _AnimatedStatCard(
                        index: 0,
                        icon: Icons.store,
                        number: '500+',
                        label: 'Garages',
                        color: isDark ? Colors.white : Colors.blue.shade700,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _AnimatedStatCard(
                        index: 1,
                        icon: Icons.access_time,
                        number: '24/7',
                        label: 'Disponible',
                        color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 12),
                      _AnimatedStatCard(
                        index: 2,
                        icon: Icons.verified,
                        number: '100%',
                        label: 'Gratuit',
                        color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Que cherchez-vous ?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Trouvez ou ajoutez un garage en quelques secondes',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildActionCard(
                    context: context,
                    icon: Icons.search,
                    title: 'Trouver un garage',
                    subtitle: 'Recherchez par ville, spécialité ou nom',
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    isDark: isDark,
                    onTap: () => context.go('/list'),
                  ),
                  const SizedBox(height: 14),
                  _buildActionCard(
                    context: context,
                    icon: Icons.add_business,
                    title: 'Ajouter mon garage',
                    subtitle: 'Inscrivez-vous gratuitement en 2 minutes',
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                    isDark: isDark,
                    onTap: () => context.go('/form'),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade200,
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.grey.shade100,
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote,
                          color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '"Panne en pleine nuit ? Garage Finder m\'a sauvé en 5 min !"',
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '🔧 Panne ? On vous sauve !',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isDark ? 4 : 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: isDark
          ? Colors.grey.shade800.withOpacity(0.7)
          : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.1),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedStatCard extends StatefulWidget {
  final int index;
  final IconData icon;
  final String number;
  final String label;
  final Color color;
  final bool isDark;

  const _AnimatedStatCard({
    required this.index,
    required this.icon,
    required this.number,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          widget.index * 0.15,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          widget.index * 0.15,
          1.0,
          curve: Curves.easeOut,
        ),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? Colors.grey.shade800.withOpacity(0.7)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.color.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: widget.isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: [
                Icon(widget.icon, size: 24, color: widget.color),
                const SizedBox(height: 4),
                Text(
                  widget.number,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}