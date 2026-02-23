package com.mlq.my_leadership_quest

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge for Android 15+ (SDK 35) compatibility
        // Using WindowCompat which works with FlutterActivity
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // For Android 15+, the system enforces edge-to-edge by default
        // The deprecated setStatusBarColor/setNavigationBarColor warnings
        // come from Flutter's internal code, not from this app code.
        // These warnings are informational and don't affect functionality.
    }
}
