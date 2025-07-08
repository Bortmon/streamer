import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
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

  void _castVideo() {
    if (_streamUrl != null) {
      _castService.castVideo(_streamUrl!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wacht tot de video laadt om te kunnen casten.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streamer'),
        actions: [
          SizedBox(
            width: 56,
            child: AndroidView(
              viewType: 'cast_button',
              layoutDirection: TextDirection.ltr,
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onLoadResource: (controller, resource) {
          final url = resource.url.toString();
          if (url.contains('master.m3u8')) {
            if (_streamUrl != url) {
              print('Master M3U8 gevonden: $url');
              setState(() {
                _streamUrl = url;
              });
            }
          }
        },
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _castVideo,
        child: const Icon(Icons.play_arrow),
        tooltip: 'Start Casting',
      ),
    );
  }
}