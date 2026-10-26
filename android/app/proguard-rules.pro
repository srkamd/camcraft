# Google ML Kit Text Recognition reflection checks for optional script options
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep ML Kit Classes
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.documentscanner.** { *; }
-keep class com.google.mlkit.vision.barcode.** { *; }
