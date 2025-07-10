import 'dart:async';
import 'package:flutter/material.dart';
import 'package:streamer/screens/cast_controller_screen.dart';
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
  String? _videoTitle;
  final List<Map<String, String>> _detectedStreams = [];
  bool _isCasting = false;

  void _handleCastButtonPress() async {
    if (_streamUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geen stream geselecteerd. Start eerst een video.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final status = await _castService.getStatus();

    if (status != null && status['isConnected'] == true) {
      _openCastController();
    } else {
      _startCasting();
    }
  }

  void _startCasting() {
    if (_streamUrl == null) return;

    final regex = RegExp(r'\/([a-f0-9]{16})\/');
    final match = regex.firstMatch(_streamUrl!);
    List<Map<String, String>> subtitles = [];

    if (match != null && match.group(1) != null) {
      final uniqueId = match.group(1)!;
      final formattedId = '${uniqueId[0]}/${uniqueId[1]}/${uniqueId[2]}/$uniqueId';
      const subtitleBaseUrl = 'https://flixtor.to/subsa/';

      subtitles = [
        {'url': '$subtitleBaseUrl$formattedId.English.vtt', 'name': 'English', 'lang': 'en'},
        {'url': '$subtitleBaseUrl$formattedId.Dutch.vtt', 'name': 'Dutch', 'lang': 'nl'},
      ];
    } else {
      print("Kon geen ID vinden in stream URL, ondertitels worden niet meegestuurd.");
    }

    _castService.startSmartCasting(
      _streamUrl!,
      _videoTitle ?? 'Onbekende video',
      subtitles,
    );

    setState(() {
      _isCasting = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      _openCastController();
    });
  }

  void _openCastController() {
    if (_streamUrl == null) return;

    final regex = RegExp(r'\/([a-f0-9]{16})\/');
    final match = regex.firstMatch(_streamUrl!);
    List<Map<String, String>> subtitlesForUi = [];
    if (match != null && match.group(1) != null) {
      final uniqueId = match.group(1)!;
      final formattedId = '${uniqueId[0]}/${uniqueId[1]}/${uniqueId[2]}/$uniqueId';
      const subtitleBaseUrl = 'https://flixtor.to/subsa/';
      subtitlesForUi = [
        {'url': '$subtitleBaseUrl$formattedId.English.vtt', 'name': 'English', 'lang': 'en'},
        {'url': '$subtitleBaseUrl$formattedId.Dutch.vtt', 'name': 'Dutch', 'lang': 'nl'},
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CastControllerScreen(
        videoUrl: _streamUrl!,
        videoTitle: _videoTitle ?? 'Onbekende video',
        availableSubtitles: subtitlesForUi,
      ),
    ).whenComplete(_updateCastingStatus);
  }

  void _updateCastingStatus() async {
    final status = await _castService.getStatus();
    if (mounted && status != null) {
      setState(() {
        _isCasting = status['isConnected'] ?? false;
      });
    }
  }

  void _showDetectedUrls() {
    if (_detectedStreams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen streams gedetecteerd')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gedetecteerde Streams'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _detectedStreams.length,
            itemBuilder: (context, index) {
              final stream = _detectedStreams[index];
              return ListTile(
                title: Text(
                  stream['title'] ?? 'Onbekende video',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow_rounded),
                  onPressed: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _streamUrl = stream['url'];
                      _videoTitle = stream['title'];
                    });
                    _startCasting();
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
        function isMasterStream(url) { return url.includes('master.m3u8') || url.includes('playlist.m3u8') || url.includes('.m3u8'); }
        function extractVideoTitle() {
          const mainTitle = document.querySelector('.watch-header');
          if (mainTitle) return mainTitle.textContent.trim();
          const fallbackTitle = document.querySelector('h1, .title, .video-title, .movie-title');
          if (fallbackTitle) return fallbackTitle.textContent.trim();
          const pageTitle = document.querySelector('title');
          if (pageTitle) return pageTitle.textContent.trim();
          return 'Video Stream';
        }
        function reportStream(url) {
          const title = extractVideoTitle();
          window.flutter_inappwebview.callHandler('streamDetected', { url: url, title: title });
        }
        const originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function(method, url) { if (isMasterStream(url)) { reportStream(url); } return originalOpen.apply(this, arguments); };
        const originalFetch = window.fetch;
        window.fetch = function(url, options) { if (typeof url === 'string' && isMasterStream(url)) { reportStream(url); } return originalFetch.apply(this, arguments); };
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
              label: Text('${_detectedStreams.length}'),
              isLabelVisible: _detectedStreams.isNotEmpty,
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
                ? 'Stream geselecteerd: ${_videoTitle ?? 'Onbekende video'}'
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
                    final data = args[0] as Map<String, dynamic>;
                    final url = data['url'] as String;
                    final title = data['title'] as String? ?? 'Onbekende video';
                    if (mounted) {
                      setState(() {
                        if (!_detectedStreams.any((s) => s['url'] == url)) {
                          _detectedStreams.add({'url': url, 'title': title});
                        }
                        _streamUrl = url;
                        _videoTitle = title;
                      });
                    }
                  },
                );
              },
              onLoadStop: (controller, url) {
                _injectStreamDetector();
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                setState(() {
                  _detectedStreams.clear();
                  _streamUrl = null;
                  _videoTitle = null;
                  _isCasting = false;
                });
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
        onPressed: _handleCastButtonPress,
        backgroundColor: _streamUrl != null ? Colors.red : Colors.grey,
        child: Icon(_isCasting ? Icons.cast_connected : Icons.cast),
        tooltip: 'Start of beheer Casting',
      ),
    );
  }
}