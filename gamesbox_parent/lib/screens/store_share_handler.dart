import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:http/http.dart' as http;
import '../services/games_service.dart';
import '../models/game_model.dart';

class StoreShareHandler extends StatefulWidget {
  const StoreShareHandler({super.key});

  @override
  State<StoreShareHandler> createState() => _StoreShareHandlerState();
}

class _StoreShareHandlerState extends State<StoreShareHandler> {
  StreamSubscription? _sub;
  String? _lastSharedText;
  String? _extractedPackage;
  String? _extractedStore; // 'play' or 'appstore'
  String? _extractedTitle;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    // handle initial share (when app launched via share)
    ReceiveSharingIntent.getInitialText().then((value) {
      if (value != null && value.isNotEmpty) _handleSharedText(value);
    });

    // handle while app is running
    _sub = ReceiveSharingIntent.getTextStream().listen((value) {
      if (value != null && value.isNotEmpty) _handleSharedText(value);
    }, onError: (err) {
      // ignore
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handleSharedText(String text) async {
    setState(() {
      _lastSharedText = text;
      _processing = true;
      _extractedPackage = null;
      _extractedStore = null;
      _extractedTitle = null;
    });

    final parsed = _parseStoreUrl(text);
    final store = parsed['store'];
    final pkg = parsed['package'];
    final appId = parsed['appId'];

    if (store == 'play' && pkg != null) {
      _extractedStore = 'play';
      _extractedPackage = pkg;
      _extractedTitle = await _fetchPlayStoreTitle(pkg);
    } else if (store == 'appstore' && appId != null) {
      _extractedStore = 'appstore';
      _extractedPackage = appId;
      // iOS scraping not implemented; use appId as title fallback
      _extractedTitle = null;
    } else {
      // try fallback extraction for any id patterns
      final fallback = _fallbackExtract(text);
      if (fallback != null) {
        _extractedStore = fallback['store'];
        _extractedPackage = fallback['package'];
        if (_extractedStore == 'play') _extractedTitle = await _fetchPlayStoreTitle(_extractedPackage!);
      }
    }

    setState(() => _processing = false);

    if (_extractedPackage == null) {
      // show cannot extract
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not extract app id from shared text')));
      }
    } else {
      // show preview dialog
      if (mounted) {
        _showConfirmDialog();
      }
    }
  }

  Map<String, String?> _parseStoreUrl(String url) {
    final uri = Uri.tryParse(url) ?? Uri();
    final host = uri.host;

    // Google Play link
    if (host.contains('play.google.com') || url.contains('market://')) {
      final q = uri.queryParameters;
      final id = q['id'];
      if (id != null && id.isNotEmpty) return {'store': 'play', 'package': id, 'appId': null};
      final m = RegExp(r'id=([A-Za-z0-9\._]+)').firstMatch(url);
      if (m != null) return {'store': 'play', 'package': m.group(1), 'appId': null};
    }

    // Apple App Store
    if (host.contains('apps.apple.com')) {
      final m = RegExp(r'id(\d+)').firstMatch(url);
      if (m != null) return {'store': 'appstore', 'package': null, 'appId': m.group(1)};
    }

    return {'store': null, 'package': null, 'appId': null};
  }

  Map<String, String?>? _fallbackExtract(String text) {
    // try to find id=com.xyz or id123456
    final m = RegExp(r'id=([A-Za-z0-9\._]+)').firstMatch(text);
    if (m != null) return {'store': 'play', 'package': m.group(1)};
    final m2 = RegExp(r'id(\d+)').firstMatch(text);
    if (m2 != null) return {'store': 'appstore', 'package': m2.group(1)};
    return null;
  }

  Future<String?> _fetchPlayStoreTitle(String packageId) async {
    try {
      final url = 'https://play.google.com/store/apps/details?id=$packageId&hl=en&gl=US';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final body = resp.body;
        final m = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(body);
        if (m != null) return m.group(1);
        final m2 = RegExp(r'<h1[^>]*>([^<]+)<').firstMatch(body);
        if (m2 != null) return m2.group(1)?.trim();
      }
    } catch (e) {
      // ignore errors
    }
    return null;
  }

  Future<void> _showConfirmDialog() async {
    final title = _extractedTitle ?? _extractedPackage!;
    final pkg = _extractedPackage!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add app to Games list?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: $title'),
              const SizedBox(height: 8),
              Text('Package/AppId: $pkg'),
              const SizedBox(height: 12),
              const Text('Do you want to add this app to the games list?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Save to DB
      final gs = GamesService();
      final gm = GameModel(id: '', name: title, packageId: pkg);
      try {
        await gs.addGame(gm);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Game added')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add game: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Game from Store')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Instructions:'),
            const SizedBox(height: 8),
            const Text('- Open Play Store / App Store') ,
            const Text('- Tap Share → choose GamesBox Parent') ,
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text('Last shared text:\n${_lastSharedText ?? "(none)"}'),
            const SizedBox(height: 12),
            if (_processing) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                // manual test dialog to paste a link
                final controller = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Paste store URL'),
                    content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'https://play.google.com/...')),
                    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Process'))],
                  ),
                );
                if (ok == true && controller.text.isNotEmpty) {
                  _handleSharedText(controller.text.trim());
                }
              },
              child: const Text('Paste store URL / Test'),
            ),
          ],
        ),
      ),
    );
  }
}
