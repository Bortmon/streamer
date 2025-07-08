// lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  InAppWebViewController? webViewController;
  final String initialUrl = "https://google.com";

  void _castVideo() {
    print("Cast knop ingedrukt.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streamer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast),
            onPressed: _castVideo,
            tooltip: 'Cast naar apparaat',
          ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true, 
          mediaPlaybackRequiresUserGesture: false, 
          useWideViewPort: true,
          loadWithOverviewMode: true,
        ),
      ),
    );
  }
}