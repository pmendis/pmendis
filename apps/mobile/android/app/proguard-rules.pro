# R8 rules for the release build. Flutter applies this file automatically.

# shared_preferences 2.5+ calls its Android code over JNI, which R8 cannot
# see. Without this, R8 strips methods like SharedPreferencesApiRegistrar
# .getAll(...) and the app fails on its first line (stuck on the splash
# screen). The plugin's @Keep annotation protects only the class names.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
