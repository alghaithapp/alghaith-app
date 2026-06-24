# Agora RTC — required for release builds (R8 must not strip SDK classes).
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# Flutter deferred components reference Play Core; app does not bundle it.
-dontwarn com.google.android.play.core.**

# Flutter / plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }