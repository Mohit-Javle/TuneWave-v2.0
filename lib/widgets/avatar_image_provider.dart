// lib/widgets/avatar_image_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';

ImageProvider getAvatarImageProvider(String? imageUrl, String placeholderUrl) {
  final url = (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : placeholderUrl;
  
  if (url.startsWith('data:image')) {
    final base64String = url.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
    try {
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return NetworkImage(placeholderUrl);
    }
  }
  return NetworkImage(url);
}
