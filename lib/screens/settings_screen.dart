import 'dart:math';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/cache_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSize = "0.0 B";

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int tempDirSize = _getDirSize(tempDir);

      setState(() {
        _cacheSize = _formatBytes(tempDirSize);
      });
    } catch (e) {
      print(e);
    }
  }

  int _getDirSize(Directory dir) {
    int size = 0;
    try {
      if (dir.existsSync()) {
        dir.listSync(recursive: true, followLinks: false).forEach((FileSystemEntity entity) {
          if (entity is File) {
            size += entity.lengthSync();
          }
        });
      }
    } catch (_) {}
    return size;
  }

  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> _clearAppCache() async {
    try {
      await CacheHelper.clearApiCacheOnly();

      await DefaultCacheManager().emptyCache();

      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }

      await _calculateCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تنظيف الذاكرة المؤقتة بنجاح"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("Error clearing cache: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          "الإعدادات",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, child) {
          return ListView(
            padding: const EdgeInsets.all(18),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionHeader("الحساب الشخصي"),
              auth.user == null
                  ? _buildGoogleSignInButton(auth)
                  : _buildUserProfile(auth),

              const SizedBox(height: 20),
              _buildPremiumCard(context, auth),

              const SizedBox(height: 28),
              _buildSectionHeader("المظهر"),
              _buildSettingsCard(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("حجم الخط", style: TextStyle(color: Colors.white, fontSize: 14)),
                              Text(
                                "${(settings.textScale * 100).toInt()}%",
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text("A", style: TextStyle(color: Colors.white, fontSize: 12)),
                              Expanded(
                                child: Slider(
                                  value: settings.textScale,
                                  min: 0.5,
                                  max: 1.5,
                                  divisions: 12,
                                  activeColor: Colors.redAccent,
                                  inactiveColor: Colors.grey[800],
                                  onChanged: (val) {
                                    settings.setTextScale(val);
                                  },
                                ),
                              ),
                              const Text("A", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]
              ),

              const SizedBox(height: 28),
              _buildSectionHeader("تفضيلات المحتوى"),

              _buildSettingsCard(
                children: [
                  _buildDropdownTile(
                    context: context,
                    auth: auth,
                    icon: Icons.hd_outlined,
                    title: "جودة المشاهدة المفضلة",
                    value: settings.preferredWatchQuality,
                    items: ['1080', '720', '480'],
                    checkPremium: false,
                    onChanged: (val) {
                      if (val != null) settings.setWatchQuality(val);
                    },
                  ),
                  _divider(),
                  _buildDropdownTile(
                    context: context,
                    auth: auth,
                    icon: Icons.download_for_offline_outlined,
                    title: "جودة التحميل المفضلة",
                    value: settings.preferredDownloadQuality,
                    items: ['1080', '720', '480'],
                    checkPremium: true,
                    onChanged: (val) {
                      if (val != null) settings.setDownloadQuality(val);
                    },
                  ),
                  _divider(),
                  SwitchListTile(
                    activeColor: Colors.redAccent,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const Icon(Icons.sort, color: Colors.white38),
                    title: const Text(
                      "ترتيب الحلقات تنازلياً",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      settings.sortDescending
                          ? "من الأحدث للأقدم"
                          : "من الأقدم للأحدث",
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    value: settings.sortDescending,
                    onChanged: (val) => settings.setSortDescending(val),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              _buildSectionHeader("طريقة السيرفرات"),

              _buildSettingsCard(
                children: [
                  SwitchListTile(
                    activeColor: Colors.redAccent,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const Icon(Icons.play_circle_outline,
                        color: Colors.white38),
                    title: const Text(
                      "تفضيل Stream للمشاهدة",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.preferHlsWatching
                              ? "Stream مفضل للمشاهدة"
                              : "Direct مفضل للمشاهدة",
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        if (settings.preferHlsWatching)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              "✔ تشغيل أسرع وأفضل مع الحلقات الطويلة بدون تقطيع",
                              style: TextStyle(
                                  color: Colors.greenAccent, fontSize: 11),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              "✔ روابط مباشرة مناسبة للأجهزة الضعيفة",
                              style: TextStyle(
                                  color: Colors.blueAccent, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    value: settings.preferHlsWatching,
                    onChanged: (val) =>
                        settings.setPreferHlsWatching(val),
                  ),
                  _divider(),
                  SwitchListTile(
                    activeColor: Colors.redAccent,
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    secondary: const Icon(Icons.file_download_outlined,
                        color: Colors.white38),
                    title: const Text(
                      "تفضيل Stream للتحميل",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settings.preferHlsDownload
                              ? "Stream مفضل للتحميل"
                              : "Direct مفضل للتحميل",
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        if (settings.preferHlsDownload)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              "⚡ سريع جدًا لكن الفيديو يبقى داخل التطبيق فقط (محمي ولا يمكن مشاركته)",
                              style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              "✔ يتم حفظ الفيديو كملف MP4 ويمكنك مشاركته وتشغيله في أي مكان",
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    value: settings.preferHlsDownload,
                    onChanged: (val) =>
                        settings.setPreferHlsDownload(val),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: const Divider( color: Colors.grey,),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
                ),
                title: const Text(
                  "مسح التخزين المؤقت",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "المساحة المستخدمة: $_cacheSize\n(لن يتم حذف التنزيلات المحفوظة)",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white30),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1C1C1C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text("تنظيف الذاكرة", style: TextStyle(color: Colors.white)),
                      content: Text(
                        "هل تريد مسح $_cacheSize من الملفات المؤقتة؟\nسيتم إعادة تحميل صور وبيانات الصفحة الرئيسية.",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _clearAppCache();
                          },
                          child: const Text("مسح الآن", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),
              _buildSectionHeader("التواصل والدعم"),
              _buildTelegramCard(context),

              const SizedBox(height: 40),

              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Center(
                      child: Text(
                        "Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})",
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 12),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _divider() {
    return Divider(color: Colors.white.withOpacity(0.05), height: 1);
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1F1F), Color(0xFF181818)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 5),
            color: Colors.black.withOpacity(0.35),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTelegramCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse('https://t.me/cima_box_app');
        if (!await launchUrl(url,
            mode: LaunchMode.externalApplication)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("فشل فتح الرابط")));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF229ED9), Color(0xFF1E88E5)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 5),
              color: Colors.blue.withOpacity(0.25),
            ),
          ],
        ),
        child: Row(
          children: const [
            Icon(Icons.telegram, color: Colors.white, size: 34),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                "انضم لقناتنا على تيليجرام للدعم والتحديثات",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, AuthProvider auth) {
    bool isPremium = auth.isPremium;

    return GestureDetector(
      onTap: () => _showPremiumDialog(context, auth),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: isPremium
                ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                : [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 6),
              color: Colors.black.withOpacity(0.35),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium,
                size: 34,
                color: isPremium ? Colors.white : Colors.amber),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                isPremium
                    ? "أنت عضو VIP 🎉"
                    : "ترقية إلى Premium للحصول على مميزات إضافية",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPremiumDialog(BuildContext context, AuthProvider auth) {
    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى تسجيل الدخول أولاً")),
      );
      auth.signInWithGoogle();
      return;
    }

    if (auth.isPremium) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 25),
              const Icon(Icons.workspace_premium,
                  size: 70, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                "كن عضواً مميزاً",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withOpacity(0.25),
                      Colors.orange.withOpacity(0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer_rounded,
                        color: Colors.amber, size: 18),
                    const SizedBox(width: 6),

                    const Text(
                      "(80 جنيه)",
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(width: 6),

                    const Text(
                      "/ 1.5\$ شهرياً",
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              _buildFeatureItem(Icons.hd, "تحميل بجودة FHD 1080p"),
              _buildFeatureItem(Icons.playlist_add_check,
                  "تحميل المواسم كاملة بضغطة واحدة"),
              _buildFeatureItem(Icons.speed, "سيرفرات خاصة وسريعة جداً"),
              _buildFeatureItem(Icons.block, "تجربة خالية تماماً من الإعلانات"),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://t.me/M2HM00D');
                    await launchUrl(url,
                        mode: LaunchMode.externalApplication);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "اشترك الآن عبر تيليجرام",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton(AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: MaterialButton(
        onPressed: auth.isSigningIn
            ? null
            : () async {
          await auth.signInWithGoogle();
        },
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (auth.isSigningIn)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            else ...[
              CachedNetworkImage(
                imageUrl:
                "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png",
                width: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                "تسجيل الدخول باستخدام Google",
                style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          auth.user!.displayName ?? "مستخدم CimaBox",
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
        subtitle: Text(
          auth.user!.email ?? "",
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[800],
          backgroundImage: auth.user!.photoURL != null
              ? NetworkImage(auth.user!.photoURL!)
              : null,
          child: auth.user!.photoURL == null
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () async {
            await auth.signOut();
          },
        ),
      ),
    );
  }

  Widget _buildDropdownTile({
    required BuildContext context,
    required AuthProvider auth,
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    bool checkPremium = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF2B2B2B),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white70),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              items: items.map((item) {
                bool locked = checkPremium && item == "1080" && !auth.isPremium;
                return DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Text("${item}p",
                          style: TextStyle(
                              color: locked ? Colors.grey : Colors.white)),
                      if (locked)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.lock,
                              size: 14, color: Colors.grey),
                        )
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (checkPremium && val == "1080" && !auth.isPremium) {
                  _showPremiumDialog(context, auth);
                } else {
                  onChanged(val);
                }
              },
            ),
          )
        ],
      ),
    );
  }
}