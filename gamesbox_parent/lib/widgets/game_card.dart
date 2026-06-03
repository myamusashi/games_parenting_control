import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final String name;
  final bool enabled;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GameCard({super.key, required this.name, required this.enabled, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(enabled ? 'Enabled' : 'Disabled'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
