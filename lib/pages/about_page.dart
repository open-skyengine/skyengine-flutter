import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';
import 'changelog_page.dart';
import 'debug_page.dart';

typedef AppVersionLoader = Future<String> Function();
typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

const _githubRepositoryUrl = 'https://github.com/open-skyengine';

class AboutPage extends StatefulWidget {
  final Future<void> Function()? onCheckForUpdate;
  final bool checkingForUpdate;
  final ValueListenable<bool>? checkingForUpdateListenable;
  final AppVersionLoader? versionLoader;
  final ChangelogLoader? changelogLoader;
  final ExternalUrlLauncher? externalUrlLauncher;

  const AboutPage({
    super.key,
    this.onCheckForUpdate,
    this.checkingForUpdate = false,
    this.checkingForUpdateListenable,
    this.versionLoader,
    this.changelogLoader,
    this.externalUrlLauncher,
  });

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final Future<String> _version;
  bool _checkingLocally = false;

  @override
  void initState() {
    super.initState();
    _version = (widget.versionLoader ?? _loadAppVersion)();
  }

  Future<void> _checkForUpdate() async {
    final check = widget.onCheckForUpdate;
    final checkingExternally =
        widget.checkingForUpdateListenable?.value ?? widget.checkingForUpdate;
    if (_checkingLocally || checkingExternally || check == null) {
      return;
    }
    setState(() => _checkingLocally = true);
    try {
      await check();
    } finally {
      if (mounted) {
        setState(() => _checkingLocally = false);
      }
    }
  }

  Future<void> _openGitHub() async {
    final uri = Uri.parse(_githubRepositoryUrl);
    try {
      final opened = await (widget.externalUrlLauncher ?? _launchExternal)(uri);
      if (!opened && mounted) {
        _showOpenUrlError();
      }
    } catch (_) {
      if (mounted) {
        _showOpenUrlError();
      }
    }
  }

  void _showOpenUrlError() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.openGitHubFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final checkingListenable = widget.checkingForUpdateListenable;
    if (checkingListenable == null) {
      return _buildPage(widget.checkingForUpdate || _checkingLocally);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: checkingListenable,
      builder: (context, checkingExternally, _) {
        return _buildPage(checkingExternally || _checkingLocally);
      },
    );
  }

  Widget _buildPage(bool checkingForUpdate) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.currentVersion),
            subtitle: FutureBuilder<String>(
              future: _version,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(l10n.versionLabel(snapshot.data!));
                }
                if (snapshot.hasError) {
                  return Text(l10n.versionInfoUnavailable);
                }
                return Text(l10n.versionReading);
              },
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ChangelogPage(changelogLoader: widget.changelogLoader),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: Text(l10n.debug),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const DebugToolsPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(l10n.checkForUpdates),
            subtitle: checkingForUpdate ? Text(l10n.checkingForUpdates) : null,
            trailing: checkingForUpdate
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onTap: checkingForUpdate || widget.onCheckForUpdate == null
                ? null
                : () => unawaited(_checkForUpdate()),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Github'),
            subtitle: const Text('github.com/open-skyengine'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => unawaited(_openGitHub()),
          ),
        ],
      ),
    );
  }
}

Future<String> _loadAppVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();
  if (buildNumber.isEmpty) {
    return version;
  }
  return '$version ($buildNumber)';
}

Future<bool> _launchExternal(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class DebugToolsPage extends StatelessWidget {
  const DebugToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.debug)),
      body: const DebugPage(),
    );
  }
}
