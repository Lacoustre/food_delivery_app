import 'package:flutter/material.dart';

/// Renders a meal image from whatever `image_url` happens to hold.
///
/// Meal photos live in Supabase Storage and arrive as full URLs, but the app
/// still falls back to bundled assets (and to the logo) when a meal has no
/// photo — so every render site has to branch on the value rather than assume
/// one kind. Getting that branch wrong is silent until real photos land: an
/// `Image.asset` handed a URL throws, and an `Image.network` handed an asset
/// path fails to load.
///
/// Keep image rendering going through here so that branch exists in one place.
class MealImage extends StatelessWidget {
  const MealImage(
    this.source, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  /// A remote URL, an `assets/...` path, or null/empty.
  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;

  static const _fallbackAsset = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    final src = source?.trim() ?? '';

    if (src.isEmpty) return _asset(_fallbackAsset);

    if (src.startsWith('http')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _asset(_fallbackAsset),
      );
    }

    // Bundled asset — a bare filename means assets/images/.
    final path = src.startsWith('assets/') ? src : 'assets/images/$src';
    return _asset(path);
  }

  Widget _asset(String path) => Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => Image.asset(
      _fallbackAsset,
      width: width,
      height: height,
      fit: fit,
    ),
  );
}
