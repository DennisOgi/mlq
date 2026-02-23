import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';

class VideoSplashScreen extends StatefulWidget {
  final String videoAssetPath;
  final Widget nextScreen;
  final Duration minDisplayTime;

  const VideoSplashScreen({
    Key? key,
    required this.videoAssetPath,
    required this.nextScreen,
    this.minDisplayTime = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  _VideoSplashScreenState createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;
  Timer? _minDisplayTimer;

  @override
  void initState() {
    super.initState();
    // Hide status bar during splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.asset(widget.videoAssetPath);
      
      await _videoPlayerController.initialize();
      if (!mounted) return;
      
      // Initialize Chewie controller
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        showControls: false,
        allowFullScreen: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
      );

      setState(() {
        _isVideoInitialized = true;
      });

      // Set minimum display time
      _minDisplayTimer = Timer(widget.minDisplayTime, _navigateToNextScreen);
      
      // Listen for video completion
      _videoPlayerController.addListener(_onVideoUpdate);
    } catch (e) {
      // If video fails to load, proceed to next screen after minimum display time
      if (mounted) {
        _minDisplayTimer = Timer(widget.minDisplayTime, _navigateToNextScreen);
      }
    }
  }

  void _onVideoUpdate() {
    if (_videoPlayerController.value.isPlaying && 
        _videoPlayerController.value.position >= _videoPlayerController.value.duration) {
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    _minDisplayTimer?.cancel();
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _minDisplayTimer?.cancel();
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          if (_isVideoInitialized && _chewieController != null)
            Center(
              child: AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          
          // Skip button
          if (_isVideoInitialized)
            Positioned(
              top: 40,
              right: 20,
              child: TextButton(
                onPressed: _navigateToNextScreen,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
