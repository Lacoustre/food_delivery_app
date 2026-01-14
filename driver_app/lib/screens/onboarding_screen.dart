import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_screen.dart';
import '../widgets/app_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const _kOnboardingSeen = 'onboarding_seen_v1';

  final PageController _pageController = PageController();
  late AnimationController _fadeAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentPage = 0;
  bool _saving = false;
  bool _isAnimating = false;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.restaurant_menu,
      title: 'Authentic Taste of African Cuisine',
      description:
          'Deliver delicious traditional African dishes to hungry customers across the city. Join our mission to bring authentic flavors to every doorstep.',
      color: Color(0xFFE65100),
      backgroundImage: 'assets/images/african_food_bg.jpg',
    ),
    _OnboardingPage(
      icon: Icons.delivery_dining,
      title: 'Fast & Reliable Delivery',
      description:
          'Use real-time GPS tracking, optimized routes, and provide excellent customer service. Your customers will love the speed and reliability.',
      color: Color(0xFFFFB300),
      backgroundImage: 'assets/images/delivery_bg.jpg',
    ),
    _OnboardingPage(
      icon: Icons.payments,
      title: 'Earn Great Money',
      description:
          'Get paid instantly for each delivery, track your daily earnings, and enjoy flexible working hours. Start earning from day one.',
      color: Color(0xFF2E7D32),
      backgroundImage: 'assets/images/earnings_bg.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Start initial animation
    _fadeAnimationController.forward();
    _slideAnimationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    if (_saving) return;
    setState(() => _saving = true);

    // Haptic feedback (no-op on platforms that don’t support it)
    HapticFeedback.lightImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kOnboardingSeen, true);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugPrint('Error saving onboarding preference: $e');
      // Continue anyway
    } finally {
      if (!mounted) return;
      // Fade out content before navigation
      await _fadeAnimationController.reverse();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => const AuthScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  Future<void> _next() async {
    if (_isAnimating) return;
    HapticFeedback.selectionClick();

    if (_currentPage < _pages.length - 1) {
      setState(() => _isAnimating = true);

      // Animate out current content
      await Future.wait([
        _fadeAnimationController.reverse(),
        _slideAnimationController.reverse(),
      ]);

      // Change page
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );

      // Animate in new content
      await Future.wait([
        _fadeAnimationController.forward(),
        _slideAnimationController.forward(),
      ]);

      if (mounted) setState(() => _isAnimating = false);
    } else {
      await _completeOnboarding();
    }
  }

  Future<void> _previous() async {
    if (_isAnimating || _currentPage == 0) return;
    HapticFeedback.selectionClick();

    setState(() => _isAnimating = true);

    await Future.wait([
      _fadeAnimationController.reverse(),
      _slideAnimationController.reverse(),
    ]);

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );

    await Future.wait([
      _fadeAnimationController.forward(),
      _slideAnimationController.forward(),
    ]);

    if (mounted) setState(() => _isAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _pages[_currentPage].color;
    final bool useLightOverlay = accent.computeLuminance() < 0.5;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: useLightOverlay
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: WillPopScope(
        onWillPop: () async {
          if (_currentPage > 0 && !_isAnimating) {
            await _previous();
            return false;
          }
          return true;
        },
        child: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Optional background image
              if (_pages[_currentPage].backgroundImage != null)
                _BackgroundImage(path: _pages[_currentPage].backgroundImage!),

              // Background gradient matching splash screen
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF8E1), Colors.white],
                    stops: [0.0, 0.4],
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _pages.length,
                        physics: const ClampingScrollPhysics(),
                        itemBuilder: (context, index) => AnimatedBuilder(
                          animation: Listenable.merge([
                            _fadeAnimation,
                            _slideAnimation,
                          ]),
                          builder: (context, _) => FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: _buildPage(index, _pages[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildBottomControls(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button (only after first page)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _currentPage > 0
                ? IconButton(
                    key: const ValueKey('back_button'),
                    onPressed: _isAnimating ? null : _previous,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    tooltip: 'Back',
                  )
                : const SizedBox(
                    key: ValueKey('empty_back'),
                    width: 48,
                    height: 48,
                  ),
          ),
          const Spacer(),
          // Page indicator chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${_currentPage + 1} of ${_pages.length}',
              semanticsLabel: 'Page ${_currentPage + 1} of ${_pages.length}',
              style: const TextStyle(
                color: Color(0xFFE65100),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const Spacer(),
          // Skip
          TextButton(
            onPressed: _saving || _isAnimating ? null : _completeOnboarding,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Skip',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index, _OnboardingPage page) {
    final isFirst = index == 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Logo/Icon
          if (isFirst)
            Hero(
              tag: 'app_logo',
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: page.color.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const AppLogo(size: 100),
              ),
            )
          else
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, _) => Transform.scale(
                scale: 0.5 + (0.5 * value),
                child: Transform.rotate(
                  angle: (1 - value) * 0.5,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [page.color.withOpacity(0.8), page.color],
                      ),
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: page.color.withOpacity(0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 10,
                          offset: const Offset(-5, -5),
                        ),
                      ],
                    ),
                    child: Icon(page.icon, size: 70, color: Colors.white),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 50),

          // Title
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              page.title,
              key: ValueKey('title_$index'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: page.color,
                height: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Description
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey('desc_$index'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                page.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[800],
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),

          const SizedBox(height: 60),

          _buildFeatureHighlights(page),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlights(_OnboardingPage page) {
    List<String> features;
    switch (_currentPage) {
      case 0:
        features = [
          '🍽️ Traditional Recipes',
          '🌍 Cultural Authenticity',
          '⭐ Quality Ingredients',
        ];
        break;
      case 1:
        features = ['📍 GPS Tracking', '⚡ Fast Routes', '📞 Customer Support'];
        break;
      case 2:
        features = [
          '💰 Instant Payments',
          '📊 Earnings Tracker',
          '⏰ Flexible Hours',
        ];
        break;
      default:
        features = [];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: features.map((feature) {
          final parts = feature.split(' ');
          final emoji = parts.first;
          final text = parts.skip(1).join(' ');
          return Expanded(
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
      child: Column(
        children: [
          // Dots / progress
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => GestureDetector(
                onTap: () => _goToPage(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: _currentPage == index ? 32 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: _currentPage == index
                        ? LinearGradient(
                            colors: [
                              _pages[_currentPage].color,
                              _pages[_currentPage].color.withOpacity(0.7),
                            ],
                          )
                        : null,
                    color: _currentPage == index ? null : Colors.grey[300],
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: _currentPage == index
                        ? [
                            BoxShadow(
                              color: _pages[_currentPage].color.withOpacity(
                                0.4,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Primary action
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saving || _isAnimating ? null : _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pages[_currentPage].color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _saving || _isAnimating ? 0 : 8,
                shadowColor: _pages[_currentPage].color.withOpacity(0.4),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _saving
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        key: ValueKey('button_content'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentPage < _pages.length - 1
                                ? 'Continue'
                                : 'Get Started',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage < _pages.length - 1
                                ? Icons.arrow_forward_ios
                                : Icons.rocket_launch,
                            size: 18,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    HapticFeedback.selectionClick();

    // Restart animations for new page
    _fadeAnimationController
      ..reset()
      ..forward();
    _slideAnimationController
      ..reset()
      ..forward();
  }

  void _goToPage(int index) {
    if (index == _currentPage || _isAnimating) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String? backgroundImage;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.backgroundImage,
  });
}

class _BackgroundImage extends StatelessWidget {
  final String path;
  const _BackgroundImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withOpacity(0.25),
        BlendMode.darken,
      ),
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) =>
            const SizedBox.shrink(), // silently ignore if missing
      ),
    );
  }
}
