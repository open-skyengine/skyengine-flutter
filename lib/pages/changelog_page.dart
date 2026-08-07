import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

typedef ChangelogLoader = Future<String> Function();

const changelogAssetPath = 'CHANGELOG.MD';

class ChangelogPage extends StatefulWidget {
  final ChangelogLoader? changelogLoader;

  const ChangelogPage({super.key, this.changelogLoader});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  late Future<String> _changelog;

  @override
  void initState() {
    super.initState();
    _changelog = _loadChangelog();
  }

  Future<String> _loadChangelog() {
    return (widget.changelogLoader ?? _loadBundledChangelog)();
  }

  void _retry() {
    setState(() => _changelog = _loadChangelog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('更新日志')),
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
                  const Text('无法加载更新日志'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
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

Future<String> _loadBundledChangelog() {
  return rootBundle.loadString(changelogAssetPath);
}
