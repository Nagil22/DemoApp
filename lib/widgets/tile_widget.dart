// tile_widget.dart
import 'package:flutter/material.dart';
import '../models/tile.dart';

class TileWidget extends StatelessWidget {
  final Tile tile;
  final VoidCallback onTap;

  const TileWidget({super.key, required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: tile.color,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                tile.icon,
                size: 70.0,
              ),
              Text(
                tile.title,
                style: const TextStyle(fontSize: 17.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
