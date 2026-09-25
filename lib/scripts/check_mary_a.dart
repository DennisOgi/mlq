import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  try {
    await Supabase.initialize(
      url: 'https://hcvyumbkonrisrxbjnst.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjdnl1bWJrb25yaXNyeGJqbnN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE0NTcyOTIsImV4cCI6MjA2NzAzMzI5Mn0.6OS27VWKITYjfF5aKg7BMqxYu2wphh24O26J2-NMoew',
    );
    
    final supabase = Supabase.instance.client;
    
    // Find Mary A
    print('Searching for Mary A...');
    final response = await supabase
        .from('profiles')
        .select('*')
        .ilike('name', '%Mary A%');
        
    print('Profiles found: ${response.length}');
    
    for (var profile in response) {
      print('\nProfile: ${profile['name']} (ID: ${profile['id']})');
      print('XP: ${profile['xp']}');
      print('Monthly XP: ${profile['monthly_xp']}');
      print('Coins: ${profile['coins']}');
      
      // Check badges
      final badges = await supabase
          .from('user_badges')
          .select('id, badge_id, earned_at, badges(name, description)')
          .eq('user_id', profile['id']);
          
      print('Badges (${badges.length}):');
      for (var badge in badges) {
        print('  - ${badge['badges']['name']}: ${badge['badges']['description']} (Earned: ${badge['earned_at']})');
      }
    }
    
  } catch (e) {
    print('Error: $e');
  }
}
