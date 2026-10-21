import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProductImageWidget extends StatelessWidget {
  final String? localImagePath;
  final String? imageUrl;
  final String? productName;
  final String category;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;

  const ProductImageWidget({
    super.key,
    this.localImagePath,
    this.imageUrl,
    this.productName,
    this.category = 'General',
    this.width = 64,
    this.height = 64,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
  });

  String? _resolveAsset() {
    if (localImagePath != null && localImagePath!.isNotEmpty) {
      return localImagePath;
    }
    if (productName != null && productName!.isNotEmpty) {
      final p = productName!.toLowerCase();
      if (p.contains('onion') || p.contains('cream')) {
        return 'assets/images/real_bites/real-bites-cream-and-onion-wafers.jpg';
      }
      if (p.contains('bhujia') || p.contains('rajasthani') || p.contains('bikaneri')) {
        return 'assets/images/real_bites/real-bites-bikaneri-sev.jpg';
      }
      if (p.contains('gathiya') || p.contains('ganthiya')) {
        return 'assets/images/real_bites/real-bites-bhavnagari-ganthiya.jpg';
      }
      if (p.contains('salted') || (p.contains('wafer') && !p.contains('farali'))) {
        return 'assets/images/real_bites/real-bites-tasty-salty-wafers.jpg';
      }
      if (p.contains('chaska') || p.contains('chaat') || p.contains('chatka')) {
        return 'assets/images/real_bites/real-bites-chilli-chatka-wafers.jpg';
      }
      if (p.contains('chana')) {
        return 'assets/images/real_bites/real-bites-chana-dal.jpg';
      }
      if (p.contains('nankhatai')) {
        return 'assets/images/real_bites/real-bites-pure-ghee-whole-wheat-nankhatai.jpg';
      }
      if (p.contains('farali')) {
        return 'assets/images/real_bites/real-bites-farali-wafers.jpg';
      }
      if (p.contains('khari')) {
        return 'assets/images/real_bites/real-bites-khari.jpg';
      }
      if (p.contains('ratlami') || p.contains('sev')) {
        return 'assets/images/real_bites/real-bites-ratlami-sev.jpg';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget imageContent;
    final resolvedAsset = _resolveAsset();

    if (resolvedAsset != null && resolvedAsset.isNotEmpty) {
      imageContent = Image.asset(
        resolvedAsset,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else if (imageUrl != null && imageUrl!.startsWith('http')) {
      imageContent = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildFallback(),
      );
    } else {
      imageContent = _buildFallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: Colors.grey.shade200, width: 0.8),
        ),
        child: imageContent,
      ),
    );
  }

  Widget _buildFallback() {
    IconData icon;
    Color color;

    final catLower = category.toLowerCase();
    if (catLower.contains('wafer') || catLower.contains('chip')) {
      icon = Icons.layers_rounded;
      color = const Color(0xFFD97706);
    } else if (catLower.contains('bakery') || catLower.contains('biscuit') || catLower.contains('rusk') || catLower.contains('cookie')) {
      icon = Icons.cookie_outlined;
      color = const Color(0xFFB45309);
    } else if (catLower.contains('namkeen') || catLower.contains('sev') || catLower.contains('gathiya')) {
      icon = Icons.restaurant_rounded;
      color = const Color(0xFF0D5C46);
    } else if (catLower.contains('spices') || catLower.contains('masala')) {
      icon = Icons.flare_rounded;
      color = const Color(0xFFDC2626);
    } else {
      icon = Icons.inventory_2_outlined;
      color = const Color(0xFF0284C7);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.06), color.withOpacity(0.14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(icon, color: color, size: width * 0.42),
      ),
    );
  }
}
