import 'package:flutter/material.dart';
import 'package:in_app_ninja/in_app_ninja.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize InAppNinja SDK
  await AppNinja.init(
    'demo_api_key_123',
    baseUrl: 'http://10.0.2.2:4000', // Android emulator -> host
  );

  // Enable debug mode
  AppNinja.debug(true);

  // Set event listener
  AppNinja.setEventsListener((eventName, properties) {
    debugPrint('📊 Event: $eventName, Props: $properties');
  });

  // Register init callbacks
  AppNinja.registerInitCallback(
    () => debugPrint('✅ InAppNinja initialized successfully'),
    (error) => debugPrint('❌ InAppNinja init failed: $error'),
  );

  // Track app opened
  AppNinja.track(
    'app_opened',
    properties: {'platform': 'flutter', 'version': '1.0.0'},
  );

  runApp(const InAppNinjaExampleApp());
}

class InAppNinjaExampleApp extends StatelessWidget {
  const InAppNinjaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InAppNinja Demo',
      navigatorObservers: [NinjaRouteObserver()],
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const HomeScreen(),
      routes: {
        '/campaigns': (context) => const CampaignsScreen(),
        '/tracking': (context) => const TrackingScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Campaign> _campaigns = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    // Listen to campaign updates
    AppNinja.onCampaigns.listen((campaigns) {
      if (mounted) {
        setState(() {
          _campaigns = campaigns;
        });
      }
    });

    // Track page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNinja.trackPage('home', context);
    });
  }

  Future<void> _identifyUser() async {
    await AppNinja.identify({
      'user_id': 'demo_user_123',
      'email': 'demo@example.com',
      'name': 'Demo User',
      'plan': 'premium',
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User identified!')));
    }
  }

  Future<void> _trackEvent() async {
    await AppNinja.track(
      'demo_button_clicked',
      properties: {
        'button_name': 'test_button',
        'screen': 'home',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event tracked!')));
    }
  }

  Future<void> _fetchCampaigns() async {
    setState(() {
      _loading = true;
    });

    try {
      final campaigns = await AppNinja.fetchCampaigns();
      setState(() {
        _campaigns = campaigns;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('InAppNinja Demo'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero section
            Card(
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.flash_on, size: 64, color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    Text(
                      'InAppNinja SDK',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powerful in-app engagement and nudges for Flutter',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SDK Actions
            Text(
              'SDK Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            NinjaView(
              valueKey: 'identify_button',
              child: ElevatedButton.icon(
                onPressed: _identifyUser,
                icon: const Icon(Icons.person),
                label: const Text('Identify User'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            NinjaView(
              valueKey: 'track_button',
              child: ElevatedButton.icon(
                onPressed: _trackEvent,
                icon: const Icon(Icons.analytics),
                label: const Text('Track Event'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _fetchCampaigns,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.campaign),
              label: Text(_loading ? 'Fetching...' : 'Fetch Campaigns'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Inline Widget Demo
            Text(
              'Inline Campaign Widget',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            NinjaWidget(valueKey: 'home_banner', defaultMargin: 0),

            const SizedBox(height: 24),

            // Campaigns List
            if (_campaigns.isNotEmpty) ...[
              Text(
                'Active Campaigns (${_campaigns.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ..._campaigns.map((campaign) => _buildCampaignCard(campaign)),
            ],

            const SizedBox(height: 24),

            // Navigation
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/campaigns'),
              icon: const Icon(Icons.campaign),
              label: const Text('View All Campaigns'),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/tracking'),
              icon: const Icon(Icons.analytics),
              label: const Text('Tracking Demo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignCard(Campaign campaign) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Text(campaign.type[0].toUpperCase())),
        title: Text(campaign.title),
        subtitle: Text(campaign.description ?? campaign.type),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          AppNinja.track(
            'campaign_clicked',
            properties: {
              'campaign_id': campaign.id,
              'campaign_type': campaign.type,
            },
          );
          _showCampaignDialog(campaign);
        },
      ),
    );
  }

  void _showCampaignDialog(Campaign campaign) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(campaign.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (campaign.description != null) Text(campaign.description!),
            const SizedBox(height: 16),
            Text(
              'Type: ${campaign.type}',
              style: const TextStyle(fontSize: 12),
            ),
            Text('ID: ${campaign.id}', style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (campaign.config['button'] != null)
            ElevatedButton(
              onPressed: () {
                AppNinja.track(
                  'campaign_cta_clicked',
                  properties: {'campaign_id': campaign.id},
                );
                Navigator.pop(context);
              },
              child: Text(campaign.config['button'].toString()),
            ),
        ],
      ),
    );
  }
}

class CampaignsScreen extends StatelessWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campaigns')),
      body: StreamBuilder<List<Campaign>>(
        stream: AppNinja.onCampaigns,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No campaigns available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final campaign = snapshot.data![index];
              return Card(
                child: ListTile(
                  title: Text(campaign.title),
                  subtitle: Text(campaign.type),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTrackButton(context, 'Product Viewed', {'product_id': '123'}),
          _buildTrackButton(context, 'Add to Cart', {
            'product_id': '123',
            'quantity': 1,
          }),
          _buildTrackButton(context, 'Checkout Started', {'cart_value': 99.99}),
          _buildTrackButton(context, 'Purchase Completed', {
            'order_id': 'ORD_456',
            'total': 99.99,
          }),
        ],
      ),
    );
  }

  Widget _buildTrackButton(
    BuildContext context,
    String eventName,
    Map<String, dynamic> props,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.track_changes),
        title: Text(eventName),
        subtitle: Text(props.toString(), style: const TextStyle(fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.send),
          onPressed: () {
            AppNinja.track(
              eventName.toLowerCase().replaceAll(' ', '_'),
              properties: props,
            );
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Tracked: $eventName')));
          },
        ),
      ),
    );
  }
}
