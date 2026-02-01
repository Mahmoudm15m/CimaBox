import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("الإعدادات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer2<SettingsProvider, AuthProvider>(
        builder: (context, settings, auth, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSectionHeader("الحساب الشخصي"),
              if (auth.user == null)
                _buildGoogleSignInButton(auth)
              else
                _buildUserProfile(auth),

              const SizedBox(height: 20),

              _buildPremiumCard(context, auth),

              const SizedBox(height: 25),

              _buildSectionHeader("تفضيلات المحتوى"),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
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
                    Divider(color: Colors.white.withOpacity(0.05), height: 1),
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
                    Divider(color: Colors.white.withOpacity(0.05), height: 1),
                    SwitchListTile(
                      activeColor: Colors.redAccent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      secondary: const Icon(Icons.sort, color: Colors.grey),
                      title: const Text("ترتيب الحلقات تنازلياً", style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                        settings.sortDescending ? "من الأحدث للأقدم" : "من الأقدم للأحدث",
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      value: settings.sortDescending,
                      onChanged: (val) => settings.setSortDescending(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              _buildSectionHeader("نظام التشغيل"),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeColor: Colors.redAccent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      secondary: const Icon(Icons.play_circle_outline, color: Colors.grey),
                      title: const Text("تفضيل سيرفرات HLS للمشاهدة", style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                        settings.preferHlsWatching ? "الأولوية لسيرفرات البث (Stream)" : "الأولوية للسيرفرات المباشرة (Direct)",
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      value: settings.preferHlsWatching,
                      onChanged: (val) => settings.setPreferHlsWatching(val),
                    ),
                    Divider(color: Colors.white.withOpacity(0.05), height: 1),
                    SwitchListTile(
                      activeColor: Colors.redAccent,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      secondary: const Icon(Icons.file_download_outlined, color: Colors.grey),
                      title: const Text("تفضيل سيرفرات HLS للتحميل", style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(
                        settings.preferHlsDownload ? "تحويل HLS أثناء التحميل" : "الأولوية لملفات MP4 المباشرة (أسرع)",
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      value: settings.preferHlsDownload,
                      onChanged: (val) => settings.setPreferHlsDownload(val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

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
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTelegramCard(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse('https://t.me/cima_box_app');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          if(context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل فتح الرابط")));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF229ED9), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.telegram, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "انضم لقناتنا على تيليجرام",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "تابع آخر التحديثات أو أبلغ عن المشاكل والأخطاء",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
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
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium
                ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                : [const Color(0xFF333333), const Color(0xFF222222)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isPremium ? Colors.orangeAccent : Colors.white10),
          boxShadow: [
            BoxShadow(
              color: isPremium ? Colors.orange.withOpacity(0.2) : Colors.black26,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPremium ? Colors.white.withOpacity(0.3) : Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.workspace_premium, color: isPremium ? Colors.white : Colors.amber, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? "أنت عضو مميز (VIP)" : "ترقية إلى Premium",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPremium
                        ? "استمتع بالمشاهدة والتحميل بلا حدود"
                        : "اشتراك شهري بسعر رمزي (2\$) فقط",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
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
                width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 25),
              const Icon(Icons.workspace_premium, size: 70, color: Colors.amber),
              const SizedBox(height: 20),
              const Text(
                "كن عضواً مميزاً",
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "سعر الاشتراك: 2\$ فقط",
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 30),

              _buildFeatureItem(Icons.hd, "تحميل بجودة FHD 1080p"),
              _buildFeatureItem(Icons.playlist_add_check, "تحميل المواسم كاملة بضغطة واحدة"),
              _buildFeatureItem(Icons.speed, "سيرفرات خاصة وسريعة جداً"),
              _buildFeatureItem(Icons.block, "تجربة خالية تماماً من الإعلانات"),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://t.me/M2HM00D');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if(context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل فتح الرابط")));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  child: const Text("اشترك الآن عبر تيليجرام", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.amber, size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton(AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: MaterialButton(
        onPressed: auth.isSigningIn ? null : () async {
          await auth.signInWithGoogle();
        },
        color: Colors.white,
        disabledColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        elevation: 2,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (auth.isSigningIn)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            else ...[
              CachedNetworkImage(
                imageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png",
                width: 24,
                height: 24,
                placeholder: (context, url) => const SizedBox(width: 24),
                errorWidget: (context, url, error) => const Icon(Icons.g_mobiledata, color: Colors.blue, size: 30),
              ),
              const SizedBox(width: 12),
              const Text(
                "تسجيل الدخول باستخدام Google",
                style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          auth.user!.displayName ?? "مستخدم CimaBox",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            auth.user!.email ?? "",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[800],
          backgroundImage: auth.user!.photoURL != null
              ? NetworkImage(auth.user!.photoURL!)
              : null,
          child: auth.user!.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null,
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: "تسجيل خروج",
            onPressed: () async {
              await auth.signOut();
            },
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: const Color(0xFF2B2B2B),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                items: items.map((String item) {
                  bool isPremiumOption = item == '1080';
                  bool isLocked = checkPremium && isPremiumOption && !auth.isPremium;

                  return DropdownMenuItem<String>(
                    value: item,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${item}p", style: TextStyle(
                          color: isLocked ? Colors.grey : Colors.white,
                        )),
                        if (isPremiumOption && checkPremium) ...[
                          const SizedBox(width: 8),
                          Icon(
                            isLocked ? Icons.lock : Icons.workspace_premium,
                            color: isLocked ? Colors.grey : Colors.amber,
                            size: 14,
                          ),
                        ]
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (checkPremium && val == '1080' && !auth.isPremium) {
                    _showPremiumDialog(context, auth);
                  } else {
                    onChanged(val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}