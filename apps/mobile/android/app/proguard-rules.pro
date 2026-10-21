# R8 rules for the release build. Flutter applies this file automatically.

# shared_preferences_android is pinned to 2.4.28 in pubspec.yaml because
# 2.5+ calls its Android code over JNI, looking methods up
# by their exact signature (e.g. SharedPreferencesApiRegistrar.getAll(String,
# List, kotlin.coroutines.Continuation)). R8 cannot see JNI calls, so it may
# strip those methods or rename the Kotlin types in their signatures; either
# way the lookup fails and the app is stuck on the splash screen.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.jvm.functions.** { *; }

# Names must survive unchanged for any JNI lookup to work. The app is open
# source, so obfuscation buys nothing; shrinking and optimisation still run.
-dontobfuscate
