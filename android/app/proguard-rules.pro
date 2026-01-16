# الحفاظ على Flutter Downloader
-keep class vn.hunghd.flutterdownloader.** { *; }

# الحفاظ على WorkManager (مهم جداً جداً)
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-keep class androidx.work.impl.WorkManagerInitializer { *; }

# الحفاظ على Android Startup (غالباً تستخدمه المكتبات الحديثة)
-keep class androidx.startup.** { *; }

# منع التحذيرات
-dontwarn androidx.work.**
-dontwarn androidx.startup.**