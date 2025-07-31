import 'package:flutter/material.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingPage({super.key, this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _onboardingPages = [
    {
      'title': 'Authentic African Flavors',
      'description':
          'Experience the bold, irresistible taste of Africa’s finest dishes crafted with tradition delivered with love.',
      'tagline': 'Taste the heritage!',
      'cta': 'Explore Our Menu',
      'image': 'assets/onboarding1.png',
    },
    {
      'title': 'Easy Ordering',
      'description':
          'Craving made simple browse customize and order your favorites in just a few taps.',
      'tagline': 'Order in seconds!',
      'cta': 'Start Your Order',
      'image': 'assets/onboarding2.png',
    },
    {
      'title': 'Fast Delivery',
      'description':
          'Hot fresh and fast we bring your favorite meals to your door exactly when you want them.',
      'tagline': 'Delivered to your doorstep!',
      'cta': 'Get It Now',
      'image': 'assets/onboarding3.png',
    },
  ];

  void _completeOnboarding() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingPages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (_, index) => _buildPage(_onboardingPages[index]),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                _currentPage == _onboardingPages.length - 1
                    ? 'Get Started'
                    : 'Skip',
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingPages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.deepOrange
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          if (_currentPage < _onboardingPages.length - 1)
            Positioned(
              right: 20,
              bottom: 40,
              child: FloatingActionButton(
                backgroundColor: Colors.deepOrange,
                onPressed: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, String> page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(page['image']!, height: 300, fit: BoxFit.contain),
          const SizedBox(height: 40),
          Text(
            page['title']!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page['tagline'] ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange[700],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page['description']!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              if (_currentPage == _onboardingPages.length - 1) {
                _completeOnboarding();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: Text(
              page['cta'] ?? 'Next',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
