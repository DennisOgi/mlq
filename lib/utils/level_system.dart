class LevelSystem {
  /// Returns the current level based on total XP
  static int getLevelForXp(int xp) {
    if (xp < 1000) return 1;
    if (xp < 5000) return 2;
    if (xp < 10000) return 3;
    if (xp < 20000) return 4;
    return 5;
  }

  /// Returns the title for a given level
  static String getLevelTitle(int level) {
    switch (level) {
      case 1:
        return 'Novice Leader';
      case 2:
        return 'Rising Star';
      case 3:
        return 'Quest Explorer';
      case 4:
        return 'Team Builder';
      case 5:
      default:
        return 'Master Leader';
    }
  }

  /// Returns the title directly from XP
  static String getLevelTitleForXp(int xp) {
    return getLevelTitle(getLevelForXp(xp));
  }

  /// Returns the XP required to reach the next level
  static int getXpForNextLevel(int xp) {
    if (xp < 1000) return 1000;
    if (xp < 5000) return 5000;
    if (xp < 10000) return 10000;
    if (xp < 20000) return 20000;
    return xp; // Max level reached, no "next" level
  }

  /// Returns the base XP of the current level
  static int getBaseXpForCurrentLevel(int xp) {
    if (xp < 1000) return 0;
    if (xp < 5000) return 1000;
    if (xp < 10000) return 5000;
    if (xp < 20000) return 10000;
    return 20000;
  }

  /// Returns the progress (0.0 to 1.0) towards the next level
  static double getProgressToNextLevel(int xp) {
    if (xp >= 20000) return 1.0; // Max level
    
    int base = getBaseXpForCurrentLevel(xp);
    int next = getXpForNextLevel(xp);
    
    return (xp - base) / (next - base);
  }
}
