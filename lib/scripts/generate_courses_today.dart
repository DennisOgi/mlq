// Script to manually generate mini courses for today
// Run with: dart run lib/scripts/generate_courses_today.dart

import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🎓 Generating mini courses for today...\n');
  
  try {
    // Initialize Supabase (you'll need to add your credentials)
    await Supabase.initialize(
      url: 'https://hcvyumbkonrisrxbjnst.supabase.co',
      anonKey: 'YOUR_ANON_KEY_HERE', // Replace with actual key
    );
    
    final supabase = Supabase.instance.client;
    
    // Call the edge function
    print('📡 Calling generate_global_daily_courses edge function...');
    final response = await supabase.functions.invoke('generate_global_daily_courses');
    
    print('✅ Success!');
    print('Response: ${response.data}');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
