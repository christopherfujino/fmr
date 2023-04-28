import 'dart:async';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:file/file.dart';

import 'src/utils.dart';
import 'src/repository.dart';
import 'src/releases_json.dart';
import 'src/walker.dart';

class SyncCommand extends Command<int> {
  SyncCommand({
    required this.root,
  });

  final Directory root;

  @override
  final String name = 'sync';

  @override
  final String description = 'Sync git submodules in the virtual monorepo.';

  Future<int> run() async {
    final rest = argResults!.rest;

    if (rest.length > 2) {
      throw StateError(
        'The `fmr $name` sub-command supports at most one trailing argument, for a flutter/flutter git ref to sync to.',
      );
    }

    await startProcess(
      <String>['git', 'submodule', 'update', '--init', '--recursive'],
      verbose: true,
    );

    await downloadFile(
      'https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json',
      root.childFile('releases.json'),
    );

    if (rest.length == 1) {
      final framework = FlutterSDK(root: root);

      await startProcess(
        <String>['git', 'fetch', '--all', '--tags'],
        verbose: true,
        workingDirectory: root.childDirectory('framework').path,
      );
      await startProcess(
        <String>['git', 'checkout', rest.first],
        verbose: true,
        workingDirectory: root.childDirectory('framework').path,
      );

      // Now ensure all dependent sub-modules are sync'd to the right version
      await mapRepos<void>(
        framework,
        // We don't need to actually map, we just want to make sure they're
        // synchronized.
        (Repository _) async {},
      );
    }

    return 0;
  }
}

class StatusCommand extends Command<int> {
  StatusCommand({
    required this.root,
  }) {
    argParser.addFlag(
      'json',
      help:
          'Print machine-parseable JSON to stdout with diagnostics to stderr.',
    );
  }

  final Directory root;

  @override
  final String name = 'status';

  @override
  final String description = 'Report status of all versions.';

  Future<int> run() async {
    final framework = FlutterSDK(root: root);

    final nameVersionTree = await mapRepos<(String, String)>(
      framework,
      (Repository repo) async => (repo.name, await repo.getVersion()),
    );

    if (argResults!['json']) {
      final map = _jsonEncode(nameVersionTree);
      print(JsonEncoder.withIndent('  ').convert(map));
    } else {
      print(_prettyPrintForHumans(nameVersionTree));
    }

    return 0;
  }
}

class GenerateReports extends Command<int> {
  GenerateReports({
    required this.root,
  }) {
    argParser.addOption(
      'number',
      abbr: 'n',
      help: 'Number of snapshots to generate.',
      defaultsTo: '1',
    );
  }

  @override
  final String name = 'generate';

  @override
  final String description = 'generate JSON reports for Flutter SDK releases.';

  final Directory root;

  Future<int> run() async {
    var n = int.parse(argResults!['number']);
    final releasesJson = ReleasesJson(file: root.childFile('releases.json'));
    final framework = FlutterSDK(root: root);

    print('Fetching framework tags...');
    await startProcess(
      <String>['git', 'fetch', '--all', '--tags'],
      verbose: true,
      workingDirectory: root.childDirectory('framework').path,
    );

    for (final release in releasesJson.releases) {
      // We only namespace by version, so if the same tag appeared on multiple
      // branches we don't duplicate.
      final reportDir =
          root.childDirectory('reports').childDirectory(release.version);
      final dependenciesJson = reportDir.childFile('dependencies.json');
      if (dependenciesJson.existsSync()) {
        print('skipping ${dependenciesJson.path} as it already exists...');
        continue;
      }
      print('creating ${reportDir.path}...');
      reportDir.createSync();
      print('entering ${reportDir.path}...');

      print('checking out framework at ${release.version}...');
      await startProcess(
        <String>['git', 'checkout', release.version],
        verbose: true,
        workingDirectory: root.childDirectory('framework').path,
      );

      final nameVersionTree = await mapRepos<(String, String)>(
        framework,
        (Repository repo) async => (repo.name, await repo.getVersion()),
      );

      final map = _jsonEncode(nameVersionTree);
      final jsonString = JsonEncoder.withIndent('  ').convert(map);

      print('writing $dependenciesJson to disk...');
      dependenciesJson.writeAsStringSync(jsonString);

      print('committing report to git...');
      final repoDir = reportDir.parent;
      await startProcess(
        const <String>['git', 'checkout', 'main'],
        workingDirectory: repoDir.path,
        verbose: true,
      );
      await startProcess(
        const <String>['git', 'add', '-A'],
        workingDirectory: repoDir.path,
        verbose: true,
      );
      await startProcess(
        <String>[
          'git',
          'commit',
          '-m',
          'Added report for Flutter ${release.version}'
        ],
        workingDirectory: repoDir.path,
        verbose: true,
      );
      await startProcess(
        <String>['git', 'push', 'origin'],
        workingDirectory: repoDir.path,
        verbose: true,
      );

      n -= 1;
      if (n <= 0) {
        print('done.');
        break;
      }
    }
    return 0;
  }
}

Map<String, Object?> _jsonEncode(Node<(String, String)> root) {
  final (name, version) = root.value;
  final current = <String, Object>{
    'name': name,
    'version': version,
  };

  final dependencies =
      root.children.map<Map<String, Object?>>((Node<(String, String)> child) {
    return _jsonEncode(child);
  }).toList();

  current['dependencies'] = dependencies;

  return current;
}

String _prettyPrintForHumans(Node<(String, String)> root,
    [StringBuffer? buffer, int depth = 0]) {
  buffer ??= StringBuffer();
  final (name, version) = root.value;
  var prefix = '';
  if (depth > 0) {
    prefix = '${'  ' * depth}⮡ ';
  }
  final paddedName = '$name: '.padRight(35 - prefix.length);
  buffer.writeln('$prefix$paddedName$version');
  for (final child in root.children) {
    _prettyPrintForHumans(child, buffer, depth + 1);
  }
  return buffer.toString();
}
