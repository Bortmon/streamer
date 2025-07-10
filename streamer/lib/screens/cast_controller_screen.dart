import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:streamer/services/cast_service.dart';

class CastControllerScreen extends StatefulWidget {
  final String videoUrl;
  final String videoTitle;
  final List<Map<String, String>> availableSubtitles;

  const CastControllerScreen({
    super.key,
    required this.videoUrl,
    required this.videoTitle,
    required this.availableSubtitles,
  });

  @override
  State<CastControllerScreen> createState() => _CastControllerScreenState();
}

class _CastControllerScreenState extends State<CastControllerScreen>
    with TickerProviderStateMixin {
  final CastService _castService = CastService();
  Timer? _statusTimer;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isPlaying = true;
  bool _isConnected = true;
  double _currentPosition = 0.0;
  double _duration = 100.0;
  double _volume = 1.0;
  bool _showControls = true;
  String _currentVideoTitle = '';

  @override
  void initState() {
    super.initState();
    _currentVideoTitle = widget.videoTitle;

    // Snellere animaties voor een responsiever gevoel
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();

    _hideControlsAfterDelay();
    _startStatusTimer();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startStatusTimer() {
    _updateStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateStatus();
      }
    });
  }

  Future<void> _updateStatus() async {
    final status = await _castService.getStatus();
    if (status != null && mounted) {
      setState(() {
        _isConnected = status['isConnected'] ?? false;
        if (!_isConnected) {
          _closeWithAnimation();
        }
        _isPlaying = status['isPlaying'] ?? false;
        _currentPosition = status['currentPosition'] ?? 0.0;
        _volume = status['volume'] ?? 1.0;
        final newDuration = status['duration'] ?? 100.0;
        if (newDuration > 0) {
          _duration = newDuration;
        }
        if (status['title'] != null && status['title'].toString().isNotEmpty) {
          _currentVideoTitle = status['title'];
        }
      });
    }
  }

  void _hideControlsAfterDelay() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _hideControlsAfterDelay();
    }
  }

  void _playPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _castService.play();
    } else {
      _castService.pause();
    }
  }

  void _skipForward() {
    _seekTo(_currentPosition + 10);
  }

  void _skipBackward() {
    _seekTo(_currentPosition - 10);
  }

  void _seekTo(double position) {
    final newPosition = position.clamp(0.0, _duration);
    setState(() {
      _currentPosition = newPosition;
    });
    _castService.seekTo(newPosition);
  }

  void _stopCasting() {
    _castService.stop();
    _closeWithAnimation();
  }

  void _disconnectCast() {
    _castService.disconnect();
    _closeWithAnimation();
  }

  void _closeWithAnimation() async {
    await _slideController.reverse();
    await _fadeController.reverse();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatTime(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return "00:00";
    final duration = Duration(seconds: seconds.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  void _showSubtitleMenu() {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: const Color.fromRGBO(0, 0, 0, 0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Ondertiteling',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSubtitleOption('Uit', () {
                  _castService.setActiveSubtitle(0);
                  Navigator.of(context).pop();
                }),
                ...widget.availableSubtitles.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, String> sub = entry.value;
                  int trackId = index + 1;

                  return _buildSubtitleOption(sub['name'] ?? 'Onbekend', () {
                    _castService.setActiveSubtitle(trackId);
                    Navigator.of(context).pop();
                  });
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitleOption(String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.2)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: const Color.fromRGBO(0, 0, 0, 0.3),
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.55,
              margin: const EdgeInsets.only(top: 80),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(20, 20, 20, 0.95),
                        Color.fromRGBO(10, 10, 10, 0.98),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(255, 255, 255, 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _closeWithAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    _currentVideoTitle,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTopButton(Icons.subtitles, _showSubtitleMenu),
                                  const SizedBox(width: 8),
                                  _buildTopButton(
                                    _isConnected ? Icons.cast_connected : Icons.cast,
                                    _disconnectCast,
                                    color: _isConnected ? Colors.green : Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: GestureDetector(
                            onTap: _toggleControlsVisibility,
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(255, 255, 255, 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(255, 255, 255, 0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Icon(
                                            Icons.cast_connected,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'Casting naar TV',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 32),
                                          child: Text(
                                            _currentVideoTitle,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color.fromRGBO(255, 255, 255, 0.7),
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  AnimatedOpacity(
                                    opacity: _showControls ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: const Color.fromRGBO(0, 0, 0, 0.4),
                                      ),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  _buildModernControlButton(
                                                    icon: Icons.replay_10,
                                                    onPressed: _skipBackward,
                                                    size: 32,
                                                  ),
                                                  _buildModernControlButton(
                                                    icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                                                    onPressed: _playPause,
                                                    size: 50,
                                                    isPrimary: true,
                                                  ),
                                                  _buildModernControlButton(
                                                    icon: Icons.forward_10,
                                                    onPressed: _skipForward,
                                                    size: 32,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      _formatTime(_currentPosition),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: SliderTheme(
                                                        data: SliderTheme.of(context).copyWith(
                                                          trackHeight: 3,
                                                          thumbShape: const RoundSliderThumbShape(
                                                            enabledThumbRadius: 8,
                                                          ),
                                                          overlayShape: const RoundSliderOverlayShape(
                                                            overlayRadius: 16,
                                                          ),
                                                        ),
                                                        child: Slider(
                                                          value: _currentPosition.clamp(0.0, _duration),
                                                          min: 0,
                                                          max: _duration > 0 ? _duration : 1.0,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              _currentPosition = value;
                                                            });
                                                          },
                                                          onChangeEnd: (value) {
                                                            _seekTo(value);
                                                          },
                                                          activeColor: Colors.red,
                                                          inactiveColor: const Color.fromRGBO(255, 255, 255, 0.3),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      _formatTime(_duration),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                
                                                const SizedBox(height: 16),
                                                
                                                Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.volume_down,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                    Expanded(
                                                      child: SliderTheme(
                                                        data: SliderTheme.of(context).copyWith(
                                                          trackHeight: 2,
                                                          thumbShape: const RoundSliderThumbShape(
                                                            enabledThumbRadius: 6,
                                                          ),
                                                        ),
                                                        child: Slider(
                                                          value: _volume,
                                                          min: 0,
                                                          max: 1,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              _volume = value;
                                                            });
                                                            _castService.setVolume(value);
                                                          },
                                                          activeColor: Colors.white,
                                                          inactiveColor: const Color.fromRGBO(255, 255, 255, 0.3),
                                                        ),
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons.volume_up,
                                                      color: Colors.white,
                                                      size: 20,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isConnected 
                                      ? const Color.fromRGBO(76, 175, 80, 0.2) 
                                      : const Color.fromRGBO(244, 67, 54, 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _isConnected ? Colors.green : Colors.red,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cast_connected,
                                      color: _isConnected ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _isConnected ? 'Verbonden' : 'Niet verbonden',
                                      style: TextStyle(
                                        color: _isConnected ? Colors.green : Colors.red,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.red.shade600, Colors.red.shade700],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  // OPGELOST: Foutcorrectie
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _stopCasting,
                                    borderRadius: BorderRadius.circular(20),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.stop, color: Colors.white, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            'Stop Casting',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(IconData icon, VoidCallback onPressed, {Color? color}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildModernControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 16 : 12),
        decoration: BoxDecoration(
          color: isPrimary 
              ? const Color.fromRGBO(255, 255, 255, 0.9)
              : const Color.fromRGBO(0, 0, 0, 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.black : Colors.white,
          size: size,
        ),
      ),
    );
  }
}