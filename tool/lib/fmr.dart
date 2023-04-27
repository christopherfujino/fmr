import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';

import 'src/utils.dart';
import 'src/repository.dart';
import 'src/walker.dart';

class SyncCommand extends Command<int> {
  @override
  final String name = 'sync';

  @override
  final String description = 'Sync git submodules in the virtual monorepo.';

  Future<int> run() async {
    await startProcess(
      <String>['git', 'submodule', 'update', '--init', '--recursive'],
    );
    return 0;
  }
}

class StatusCommand extends Command<int> {
  StatusCommand({
    required this.root,
  });

  final Directory root;

  @override
  final String name = 'status';

  @override
  final String description = 'Report status of all versions.';

  Future<int> run() async {
    final framework = FlutterSDK(root: root);

    final versions = <String>[];
    await walkRepos<String>(
      framework,
      (Repository repo, int depth) async {
        final version = await repo.getVersion();
        versions.add(_formatVersion(repo.name, version, depth));
      },
    );
    print('');
    versions.forEach(print);

    return 0;
  }
}

String _formatVersion(String name, String version, int depth) {
  String prefix = '';
  if (depth > 0) {
    prefix = '${'   ' * depth}⮡> ';
  }
  return '$prefix$name: '.padRight(20) + version;
}
