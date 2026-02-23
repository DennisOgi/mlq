import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import '../services/cache_service.dart';
import '../utils/animation_optimizer.dart';

/// A widget that displays images with caching for better offline experience
class CachedImage extends StatefulWidget {
  final String imageUrl;
  final String? assetFallback;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration cacheDuration;

  const CachedImage({
    Key? key,
    required this.imageUrl,
    this.assetFallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.cacheDuration = const Duration(days: 7),
  }) : super(key: key);

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  final CacheService _cacheService = CacheService();
  File? _cachedImage;
  bool _isLoading = true;
  bool _hasError = false;
  final AnimationOptimizer _animationOptimizer = AnimationOptimizer();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Generate a cache key from the image URL
      final cacheKey = _generateCacheKey(widget.imageUrl);
      
      // Try to get the image from cache
      final cachedFile = await _cacheService.getCachedImage(cacheKey);
      
      if (cachedFile != null) {
        // Image found in cache
        if (!mounted) return;
        setState(() {
          _cachedImage = cachedFile;
          _isLoading = false;
        });
      } else {
        // Image not in cache, download it
        await _downloadAndCacheImage(widget.imageUrl, cacheKey);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadAndCacheImage(String url, String cacheKey) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Cache the downloaded image
        await _cacheService.cacheImage(
          key: cacheKey,
          imageBytes: response.bodyBytes,
          expiration: widget.cacheDuration,
        );
        
        // Get the cached file
        final cachedFile = await _cacheService.getCachedImage(cacheKey);
        
        if (!mounted) return;
        setState(() {
          _cachedImage = cachedFile;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  String _generateCacheKey(String url) {
    // Create a unique key based on the URL
    return url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    
    if (_isLoading) {
      // Show placeholder while loading
      child = widget.placeholder ?? 
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
    } else if (_hasError || _cachedImage == null) {
      // Show error widget or fallback asset
      if (widget.assetFallback != null) {
        child = Image.asset(
          widget.assetFallback!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      } else {
        child = widget.errorWidget ?? 
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.error_outline, color: Colors.red),
            ),
          );
      }
    } else {
      // Show cached image
      child = Image.file(
        _cachedImage!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
      );
    }
    
    // Apply border radius if specified
    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }
    
    // Apply optimized animations
    return child.animate(
      effects: _animationOptimizer.getOptimizedEffects(
        fadeIn: true,
        scale: !_isLoading,
      ),
    );
  }
}
