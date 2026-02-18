import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:clone_mp/services/personalization_service.dart';
import 'package:clone_mp/route_names.dart';
import 'package:clone_mp/screens/personalization/widgets/genre_selection_widget.dart';
import 'package:clone_mp/screens/personalization/widgets/artist_selection_widget.dart';
import 'package:clone_mp/screens/personalization/widgets/mood_selection_widget.dart';

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({super.key});

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5; // Welcome, Genre, Artist, Mood, Done

  // Selections
  List<String> _selectedGenres = [];
  List<String> _selectedArtists = [];
  List<String> _selectedMoods = [];
  
  bool _isSaving = false;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _skipAll() async {
    // Mark as completed but save empty preferences? 
    // Or just mark completed. The prompt says "skips entire personalization".
    // We should probably just mark it done so it doesn't show again.
    final service = Provider.of<PersonalizationService>(context, listen: false);
    await service.setPersonalizationCompleted();
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    }
  }

  Future<void> _finishFlow() async {
    setState(() {
      _isSaving = true;
    });

    // Animate to "Done" screen (Page 4, 0-indexed)
    _pageController.animateToPage(
      4, 
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeInOut
    );

    final service = Provider.of<PersonalizationService>(context, listen: false);
    try {
      // Save data FIRST
      await service.savePersonalizationData(
        genres: _selectedGenres,
        artists: _selectedArtists,
        moods: _selectedMoods,
      );
      
      // If save successful, THEN wait for animation/UX
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      }
    } catch (e) {
      // Handle error immediately if save fails
      debugPrint("Error saving personalization: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving choices: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSaving = false;
        });
        // Optionally go back to previous page? 
        // For now, staying on Done page with error is okay, 
        // or we could go back to the previous step.
      }
    }
  }

  // VALIDATION HELPERS
  bool get _canContinue {
    switch (_currentPage) {
      case 0: // Welcome
        return true;
      case 1: // Genre (min 3)
        return _selectedGenres.length >= 3;
      case 2: // Artist (min 2)
        return _selectedArtists.length >= 2;
      case 3: // Mood (no min)
        return true;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // TOP BAR (Skip & Progress)
            if (_currentPage > 0 && _currentPage < 4) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _previousPage,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentPage / 4.0, // 1/4, 2/4, 3/4
                            backgroundColor: theme.unselectedWidgetColor.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6600)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      "Step $_currentPage/4",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_currentPage == 0) ...[
              // Welcome Screen Header
               Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _skipAll,
                    child: Text(
                      "Skip", 
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      )
                    ),
                  ),
                ),
              ),
            ],

            // CONTENT
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to enforce validation
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  // PAGE 1: WELCOME
                  _buildWelcomeStep(theme),

                  // PAGE 2: GENRES
                  GenreSelectionWidget(
                    selectedGenres: _selectedGenres,
                    onSelectionChanged: (list) => setState(() => _selectedGenres = list),
                  ),

                  // PAGE 3: ARTISTS
                  ArtistSelectionWidget(
                    selectedArtists: _selectedArtists,
                    onSelectionChanged: (list) => setState(() => _selectedArtists = list),
                  ),

                  // PAGE 4: MOODS
                  MoodSelectionWidget(
                    selectedMoods: _selectedMoods,
                    onSelectionChanged: (list) => setState(() => _selectedMoods = list),
                  ),

                  // PAGE 5: DONE
                  _buildDoneStep(theme),
                ],
              ),
            ),

            // BOTTOM BAR (Button)
            if (_currentPage < 4)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canContinue 
                      ? (_currentPage == 3 ? _finishFlow : _nextPage) 
                      : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6600),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.disabledColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      _currentPage == 0 ? "Get Started" : 
                      (_currentPage == 3 ? "Finish" : "Continue"),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
             padding: const EdgeInsets.all(24),
             decoration: const BoxDecoration(
                color: Color(0xFFFF6600),
                shape: BoxShape.circle,
             ),
             child: const Icon(Icons.queue_music, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            "Let's personalize your music",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Answer a few quick questions to get music made for you",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildDoneStep(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFFFF6600)),
        const SizedBox(height: 24),
        Text(
          "You're all set! 🎉",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "We're building your personalized music experience",
          textAlign: TextAlign.center,
          style: TextStyle(
             fontSize: 16,
             color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Color(0xFFFF6600)),
      ],
    );
  }
}
