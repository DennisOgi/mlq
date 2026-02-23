## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## Gson rules
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

## Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

## Keep your models
-keep class com.mlq.my_leadership_quest.models.** { *; }

## General Android rules
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# --- Google Play Core (SplitInstall) keep rules ---
# Keep Play Core splitinstall classes used by Flutter's PlayStoreDeferredComponentManager
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep Flutter deferred components manager
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Keep SplitCompat application if referenced
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
