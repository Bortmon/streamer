import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:streamer/services/cast_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CastService _castService = CastService();
  InAppWebViewController? webViewController;
  final String initialUrl = "https://flixtor.to";
  String? _streamUrl;
  final List<String> _detectedUrls = [];

  void _startSmartCasting() {
    if (_streamUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geen stream gevonden. Start eerst een video op de website.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _castService.startSmartCasting(_streamUrl!);
  }

  void _showDetectedUrls() {
    if (_detectedUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen URLs gedetecteerd')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gedetecteerde URLs'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _detectedUrls.length,
            itemBuilder: (context, index) {
              final url = _detectedUrls[index];
              return ListTile(
                title: Text(url, style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _streamUrl = url;
                    });
                    _startSmartCasting();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  void _injectStreamDetector() async {
    if (webViewController == null) return;

    const jsCode = '''
      (function() {
        function isMasterStream(url) {
          return url.includes('master.m3u8');
        }
        const originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) {
          if (isMasterStream(url)) { window.flutter_inappwebview.callHandler('streamDetected', url); }
          return originalOpen.apply(this, arguments);
        };
        const originalFetch = window.fetch;
        window.fetch = function(url, options) {
          if (typeof url === 'string' && isMasterStream(url)) { window.flutter_inappwebview.callHandler('streamDetected', url); }
          return originalFetch.apply(this, arguments);
        };
      })();
    ''';
    
    try {
      await webViewController!.evaluateJavascript(source: jsCode);
    } catch (e) {
      print('Error injecting stream detector: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streamer'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('${_detectedUrls.length}'),
              isLabelVisible: _detectedUrls.isNotEmpty,
              child: const Icon(Icons.video_library_outlined),
            ),
            onPressed: _showDetectedUrls,
            tooltip: 'Toon gevonden streams',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: _streamUrl != null ? Colors.green.shade100 : Colors.red.shade100,
            child: Text(
              _streamUrl != null 
                ? 'Stream geselecteerd! Druk op Play om te casten.'
                : 'Geen stream gedetecteerd. Start een video op de website.',
              style: TextStyle(
                color: _streamUrl != null ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
              onWebViewCreated: (controller) {
                webViewController = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'streamDetected',
                  callback: (args) {
                    final url = args[0] as String;
                    if (mounted && !_detectedUrls.contains(url)) {
                      setState(() {
                        _detectedUrls.add(url);
                        _streamUrl = url;
                      });
                    }
                  },
                );
              },
              onLoadStop: (controller, url) {
                _injectStreamDetector();
              },
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                allowsInlineMediaPlayback: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startSmartCasting,
        backgroundColor: _streamUrl != null ? Theme.of(context).colorScheme.primary : Colors.grey,
        child: const Icon(Icons.cast_connected),
        tooltip: 'Start Casting',
      ),
    );
  }
}