// models/tile.dart
import 'package:flutter/material.dart';

class Tile {
  final String title;
  final IconData icon;
  final Color color;
  final List<Tile> subTiles;

  Tile({
    required this.title,
    required this.icon,
    required this.color,
    this.subTiles = const [],
  });
}
