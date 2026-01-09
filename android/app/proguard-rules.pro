# Flutter ProGuard Rules
# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native method names
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep custom views
-keep public class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
    *** get*();
}

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep GetX classes
-keep class com.fruitsofspirit.android.** { *; }

# Keep Hive classes
-keep class hive.** { *; }

# Keep HTTP classes
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Keep image loading classes
-keep class com.cached_network_image.** { *; }

# Keep video player classes
-keep class io.flutter.plugins.videoplayer.** { *; }

# Keep permission handler
-keep class com.baseflow.permissionhandler.** { *; }

# Keep image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep image cropper
-keep class vn.hunghd.imagecropper.** { *; }
-dontwarn vn.hunghd.imagecropper.**

# Keep share plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Keep url launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Keep app links
-keep class com.llf.applinks.** { *; }

# Keep path provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Keep Play Core classes (for deferred components)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Optimization
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

