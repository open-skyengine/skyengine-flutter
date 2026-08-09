import 'package:flutter/material.dart';

import '../services/app_store_api.dart';

class AppStoreAppIcon extends StatelessWidget {
  const AppStoreAppIcon({
    super.key,
    required this.app,
    required this.client,
    this.size = 48,
  });

  final AppStoreApp app;
  final AppStoreClient client;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconUrl = app.iconUrl;
    if (iconUrl == null || iconUrl.isEmpty) {
      return _fallbackIcon();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        client.resolveAssetUri(iconUrl).toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(app.type == 'game' ? Icons.sports_esports : Icons.apps),
      ),
    );
  }
}

class AppStoreAppTile extends StatelessWidget {
  const AppStoreAppTile({
    super.key,
    required this.app,
    required this.client,
    required this.onTap,
  });

  final AppStoreApp app;
  final AppStoreClient client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final manufacturer = app.manufacturer?.name.trim() ?? '';
    final description = app.description.trim();
    final subtitle = [
      if (manufacturer.isNotEmpty) manufacturer,
      if (description.isNotEmpty) description,
    ];
    return ListTile(
      key: ValueKey('store-app-${app.appId}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AppStoreAppIcon(app: app, client: client),
      title: Text(
        app.name.isEmpty ? app.internalName : app.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle.isEmpty ? 'APP ID: ${app.appId}' : subtitle.join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: subtitle.length > 1,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
