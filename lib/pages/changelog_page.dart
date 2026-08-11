import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../l10n/l10n.dart';

typedef ChangelogLoader = Future<String> Function();

const chineseChangelogAssetPath = 'CHANGELOG.MD';
const englishChangelogAssetPath = 'CHANGELOG_EN.MD';

class ChangelogPage extends StatefulWidget {
  final ChangelogLoader? changelogLoader;

  const ChangelogPage({super.key, this.changelogLoader});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  late Future<String> _changelog;
  String? _languageCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageCode = Localizations.localeOf(context).languageCode;
    if (_languageCode != languageCode) {
      _languageCode = languageCode;
      _changelog = _loadChangelog();
    }
  }

  Future<String> _loadChangelog() {
    final loader = widget.changelogLoader;
    if (loader != null) {
      return loader();
    }
    return _loadBundledChangelog(_languageCode ?? 'en');
  }

  void _retry() {
    setState(() => _changelog = _loadChangelog());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changeLog)),
      body: FutureBuilder<String>(
        future: _changelog,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 12),
                  Text(l10n.changeLogLoadFailed),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }
          return Markdown(
            data: snapshot.data ?? '',
            selectable: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          );
        },
      ),
    );
  }
}

Future<String> _loadBundledChangelog(String languageCode) {
  final path = languageCode == 'zh'
      ? chineseChangelogAssetPath
      : englishChangelogAssetPath;
  return rootBundle.loadString(path);
}
