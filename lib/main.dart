import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Google Mobile Ads SDK
  MobileAds.instance.initialize();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_PROJECT_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const CricketCoachApp());
}

class CricketCoachApp extends StatelessWidget {
  const CricketCoachApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Coach Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==================== HOME SCREEN WITH REAL BANNER AD ====================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdBanner();
  }

  void _loadAdBanner() {
    _bannerAd = BannerAd(
      // Using Google's official test ad unit ID for development safely
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', 
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> categories = const [
    {'title': 'Batting Masterclass', 'icon': Icons.sports_cricket, 'count': 'Drills Library', 'color': Colors.amber},
    {'title': 'Fast Bowling', 'icon': Icons.bolt, 'count': 'Drills Library', 'color': Colors.redAccent},
    {'title': 'Spin Bowling', 'icon': Icons.change_history, 'count': 'Drills Library', 'color': Colors.blueAccent},
    {'title': 'Fielding & Agility', 'icon': Icons.flash_on, 'count': 'Drills Library', 'color': Colors.greenAccent},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cricket Coach Pro', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DrillListScreen(categoryTitle: cat['title']),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(cat['icon'], color: cat['color'], size: 36),
                        const Spacer(),
                        Text(cat['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(cat['count'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Live Google AdMob Banner View Container
          if (_isBannerLoaded)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}

// ==================== DRILL LIST WITH REWARDED AD LOGIC ====================
class DrillListScreen extends StatelessWidget {
  final String categoryTitle;
  const DrillListScreen({Key? key, required this.categoryTitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      appBar: AppBar(title: Text(categoryTitle)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase.from('drills').select().eq('category', categoryTitle),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }
          final drills = snapshot.data ?? [];
          if (drills.isEmpty) {
            return const Center(child: Text('No modules added yet.', style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: drills.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final drill = drills[index];
              final bool isLocked = drill['is_locked'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Icon(isLocked ? Icons.lock : Icons.play_arrow, color: isLocked ? Colors.amber : Colors.greenAccent, size: 32),
                  title: Text(drill['title'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('Duration: ${drill['duration']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: isLocked ? const Icon(Icons.ondemand_video, color: Colors.amber) : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    if (isLocked) {
                      _loadAndShowRewardedAd(context, drill['video_url'], drill['title'], drill['description']);
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => DrillPlayerScreen(videoUrl: drill['video_url'], title: drill['title'], description: drill['description'])));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Real Google Rewarded Ad Implementation Function
  void _loadAndShowRewardedAd(BuildContext context, String videoUrl, String title, String description) {
    RewardedAd.load(
      // Using Google's test Rewarded Ad Unit ID safely
      adUnitId: 'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            // User successfully watched the entire ad! Unlock content here:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reward Earned! Unlocking Masterclass... 🎉')),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DrillPlayerScreen(videoUrl: videoUrl, title: title, description: description),
              ),
            );
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          // Fallback if test ad fails to load due to network issues
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad failed to load. Opening content directly for review.')),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DrillPlayerScreen(videoUrl: videoUrl, title: title, description: description),
            ),
          );
        },
      ),
    );
  }
}

class DrillPlayerScreen extends StatelessWidget {
  final String videoUrl;
  final String title;
  final String description;

  const DrillPlayerScreen({Key? key, required this.videoUrl, required this.title, required this.description}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 200, color: Colors.black, alignment: Alignment.center, child: const Icon(Icons.play_circle_fill, size: 64, color: Colors.greenAccent)),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
