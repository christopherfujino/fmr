import 'dart:async';
import 'dart:io' as io;
import 'dart:convert';

import 'package:file/file.dart';

import 'pubspec.dart';
import 'utils.dart';

sealed class Repository {
  const Repository({
    required this.dependencies,
    required this.name,
    required this.dir,
  });

  final Map<Type, Repository> dependencies;

  Future<void> visitDependencies<T>(
    void Function(Repository repo) callback,
  ) async {
    for (final dependency in dependencies.values) {
      await dependency.sync(this);
      callback(dependency);
    }
  }

  final String name;

  Future<String> getVersion();
  Future<String> getRevision() async {
    final io.ProcessResult result = await runProcess(
      <String>['git', 'rev-parse', 'HEAD'],
      workingDirectory: dir.path,
    );

    if (result.exitCode != 0) {
      throw result;
    }

    return (result.stdout as String).trim();
  }

  final Directory dir;

  Future<void> sync(Repository parent);
}

final class Framework extends Repository {
  Framework({
    required Directory root,
  }) : super(
          dependencies: {Engine: Engine(root: root)},
          name: 'framework',
          dir: root.childDirectory('framework'),
        );

  File get flutterBin => dir.childDirectory('bin').childFile('flutter');

  late final Future<void> _ensureToolBuilt = runProcess(
    <String>[flutterBin.path, '--version'],
  );

  Future<String> getVersion() async {
    await _ensureToolBuilt;
    final io.ProcessResult result = await runProcess(
      <String>[flutterBin.path, '--version', '--machine'],
    );

    if (result.exitCode != 0) {
      throw result;
    }

    final Map<String, Object?> json = jsonDecode(result.stdout);
    return json['frameworkVersion'] as String;
  }

  Future<void> sync(Repository parent) {
    throw UnimplementedError('The framework is the root--there is no parent!');
  }
}

final class Engine extends Repository {
  Engine({
    required Directory root,
  }) : super(
          dir: root.childDirectory('engine'),
          dependencies: {Dart: Dart(root: root)},
          name: 'engine',
        );

  Future<String> getVersion() => getRevision();

  Future<void> sync(covariant Framework parent) async {
    final revision = (await parent.dir
            .childDirectory('bin')
            .childDirectory('internal')
            .childFile('engine.version')
            .readAsString())
        .trim();

    await runProcess(<String>['git', 'checkout', revision],
        workingDirectory: dir.path);
  }
}

final class Dart extends Repository {
  Dart({
    required Directory root,
  }) : super(
          dir: root.childDirectory('dart-sdk'),
          dependencies: {Analyzer: Analyzer(root: root)},
          name: 'dart-sdk',
        );

  static final _kVersionPattern = RegExp(r'"version": "([\da-z-.]+)"');
  Future<String> getVersion() async {
    final utilsPy = dir.childDirectory('tools').childFile('utils.py');
    final result = await runProcess(<String>[
      await python,
      utilsPy.path,
    ]);
    final lines = (result.stdout as String).split('\n');
    bool inGetVersionFileContent = false;
    for (final line in lines) {
      if (inGetVersionFileContent) {
        final match = _kVersionPattern.firstMatch(line);
        if (match != null) {
          return match.group(1)!;
        }
        continue;
      }
      if (line.contains(r'GetVersionFileContent()')) {
        inGetVersionFileContent = true;
      }
    }
    throw StateError(
      'Could not parse the output of //dart-sdk/tools/utils.py:\n\n$lines',
    );
  }

  static final _kDartRevisionEngineDepsPattern =
      RegExp('\\s+\'dart_revision\': \'([0-9a-f]{40})\',');
  Future<void> sync(covariant Engine parent) async {
    final deps = (await parent.dir.childFile('DEPS').readAsString()).trim();

    final match = _kDartRevisionEngineDepsPattern.firstMatch(deps);
    if (match == null) {
      throw StateError(
        'The pattern ${_kDartRevisionEngineDepsPattern.pattern} did not match the deps file contents:\n\n$deps',
      );
    }

    final revision = match.group(1)!;

    await runProcess(
      <String>['git', 'checkout', revision],
      workingDirectory: dir.path,
    );
  }
}

// Part of Dart repo.
final class Analyzer extends Repository {
  Analyzer({
    required Directory root,
  }) : super(
          dir: root
              .childDirectory('dart-sdk')
              .childDirectory('pkg')
              .childDirectory('analyzer'),
          dependencies: const {},
          name: 'analyzer',
        );

  Future<String> getVersion() async {
    final pubspec = Pubspec.fromFile(dir.childFile('pubspec.yaml'));
    return pubspec.version;
  }

  // no-op.
  Future<void> sync(covariant Dart parent) async {}
}