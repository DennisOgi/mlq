import 'package:flutter/material.dart';

class OnboardingProvider extends ChangeNotifier {
  int _currentPage = 0;
  bool _isOnSubscriptionPage = false;

  int get currentPage => _currentPage;
  bool get isOnSubscriptionPage => _isOnSubscriptionPage;

  void setCurrentPage(int page) {
    _currentPage = page;
    // Check if this is the subscription page (page 6 in the current implementation)
    _isOnSubscriptionPage = page == 6;
    notifyListeners();
  }
}
