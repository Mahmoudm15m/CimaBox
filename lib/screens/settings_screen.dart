import 'package:flutter/material.dart';
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
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle("الحساب"),
              if (auth.user == null)
                _buildGoogleSignInButton(auth)
              else
                _buildUserProfile(auth),

              const SizedBox(height: 10),

              _buildPremiumCard(context, auth),

              const SizedBox(height: 20),

              _buildSectionTitle("المشاهدة"),
              _buildDropdownTile(
                context: context,
                auth: auth,
                title: "الجودة المفضلة للمشاهدة",
                value: settings.preferredWatchQuality,
                items: ['1080', '720', '480'],
                onChanged: (val) {
                  if (val != null) settings.setWatchQuality(val);
                },
              ),
              const SizedBox(height: 20),

              _buildSectionTitle("التنزيلات"),
              _buildDropdownTile(
                context: context,
                auth: auth,
                title: "الجودة المفضلة للتحميل",
                value: settings.preferredDownloadQuality,
                items: ['1080', '720', '480'],
                onChanged: (val) {
                  if (val != null) settings.setDownloadQuality(val);
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                activeColor: Colors.redAccent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                tileColor: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: const Text("ترتيب الحلقات والمواسم", style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  settings.sortDescending ? "من الأحدث للأقدم (تنازلي)" : "من الأقدم للأحدث (تصاعدي)",
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
                value: settings.sortDescending,
                onChanged: (val) => settings.setSortDescending(val),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, AuthProvider auth) {
    bool isPremium = auth.isPremium;
    return GestureDetector(
      onTap: () => _showPremiumDialog(context, auth),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPremium
                ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                : [const Color(0xFF2C2C2C), const Color(0xFF1A1A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isPremium ? Colors.orangeAccent : Colors.white10),
          boxShadow: [
            BoxShadow(
              color: isPremium ? Colors.orange.withOpacity(0.3) : Colors.black26,
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
              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPremium ? "أنت مشترك VIP" : "ترقية إلى Premium",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPremium ? "استمتع بكل المزايا" : "جودة (1080p)، سيرفرات صاروخية، وتحميل كامل",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isPremium)
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
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
              const SizedBox(height: 20),
              const Icon(Icons.workspace_premium, size: 60, color: Colors.amber),
              const SizedBox(height: 15),
              const Text(
                "احصل على عضوية Premium",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              _buildFeatureItem(Icons.speed, "سيرفرات فائقة السرعة لتجربة مشاهدة بدون أي تقطيع"),
              _buildFeatureItem(Icons.speed, "استكمل المشاهدة فوراً من حيث توقفت بكل سهولة"),
              _buildFeatureItem(Icons.hd, "شاهد وحمّل بأعلى جودة ممكنة (1080p) FHD"),
              _buildFeatureItem(Icons.playlist_add_check, "تحميل المواسم كاملة بضغطة واحدة وبسرعة"),
              _buildFeatureItem(Icons.block, "استمتع بتجربة مشاهدة ممتعة بدون إعلانات نهائياً"),


              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: SizedBox(
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("اشترك الآن عبر تيليجرام", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.amber, size: 24),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          auth.user!.displayName ?? "مستخدم CimaBox",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          auth.user!.email ?? "",
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey[800],
          backgroundImage: auth.user!.photoURL != null
              ? NetworkImage(auth.user!.photoURL!)
              : null,
          child: auth.user!.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          tooltip: "تسجيل خروج",
          onPressed: () async {
            await auth.signOut();
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 5),
      child: Text(
        title,
        style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDropdownTile({
    required BuildContext context,
    required AuthProvider auth,
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF2B2B2B),
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: items.map((String item) {
              bool isPremiumOption = item == '1080';
              bool isLocked = isPremiumOption && !auth.isPremium;

              return DropdownMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Text("${item}p", style: TextStyle(
                      color: isLocked ? Colors.grey : Colors.white,
                    )),
                    if (isPremiumOption) ...[
                      const SizedBox(width: 8),
                      Icon(
                        isLocked ? Icons.lock : Icons.workspace_premium,
                        color: isLocked ? Colors.grey : Colors.amber,
                        size: 16,
                      ),
                    ]
                  ],
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val == '1080' && !auth.isPremium) {
                _showPremiumDialog(context, auth);
              } else {
                onChanged(val);
              }
            },
          ),
        ],
      ),
    );
  }
}