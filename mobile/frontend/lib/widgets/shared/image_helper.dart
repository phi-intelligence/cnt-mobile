import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';

/// Helper class to create ImageProvider that handles both network and asset images
class ImageHelper {
  /// Creates an appropriate ImageProvider based on the image URL/path
  /// - If it starts with 'http://' or 'https://', uses NetworkImage
  /// - If it starts with 'assets/', uses AssetImage
  /// - Otherwise, treats it as a relative path and constructs full URL with media base URL
  static ImageProvider getImageProvider(String? imageUrl, {String? fallbackAsset}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      if (fallbackAsset != null) {
        return AssetImage(fallbackAsset);
      }
      // Return a placeholder (we'll handle this in the widget)
      return const AssetImage('assets/images/thumbnail1.jpg');
    }
    
    // Check if it's an asset path
    if (imageUrl.startsWith('assets/')) {
      return AssetImage(imageUrl);
    }
    
    // Check if it's a network URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return NetworkImage(imageUrl);
    }

    // For relative paths from backend, construct full URL using centralised media resolver
    final fullUrl = ApiService().getMediaUrl(imageUrl);
    return NetworkImage(fullUrl);
  }
  
  /// Get fallback asset image based on index
  /// Cycles through available thumbnail assets
  static String getFallbackAsset(int index) {
    final thumbnails = [
      'assets/images/thumbnail1.jpg',
      'assets/images/thumb2.jpg',
      'assets/images/thumb3.jpg',
      'assets/images/thumb4.jpg',
      'assets/images/thumb5.jpg',
      'assets/images/thumb6.jpg',
      'assets/images/thumb7.jpg',
      'assets/images/thumb8.jpg',
    ];
    return thumbnails[index % thumbnails.length];
  }

  /// Build a cached network image widget with proper error handling
  /// Returns CachedNetworkImage for network URLs, Image.asset for assets
  static Widget buildCachedImage({
    required String? imageUrl,
    required String fallbackAsset,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
    int? memCacheWidth,
    int? memCacheHeight,
  }) {
    // If no image URL, use fallback asset
    if (imageUrl == null || imageUrl.isEmpty) {
      return Image.asset(
        fallbackAsset,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return errorWidget?.call(context, '', error) ?? 
            Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image, color: Colors.grey),
            );
        },
      );
    }
    
    // Check if it's an asset path
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            fallbackAsset,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget?.call(context, imageUrl, error) ?? 
                Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, color: Colors.grey),
                );
            },
          );
        },
      );
    }
    
    // Determine full URL for network images via centralised resolver
    final fullUrl = ApiService().getMediaUrl(imageUrl);
    
    // Use CachedNetworkImage for network images
    return CachedNetworkImage(
      imageUrl: fullUrl,
      fit: fit,
      placeholder: placeholder ?? (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      ),
      errorWidget: errorWidget ?? (context, url, error) {
        // Try fallback asset on error
        return Image.asset(
          fallbackAsset,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Icon(Icons.image, color: Colors.grey),
            );
          },
        );
      },
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
    );
  }
}

