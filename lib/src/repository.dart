import 'dart:async';
import 'dart:io' as io;
import 'dart:convert';

import 'package:file/file.dart';

import 'utils.dart';

sealed class Repository {
  const Repository({
    required this.dependencies,
    required this.name,
    required this.dir,
  });

  final Map<Type, Repository> dependencies;

  Iterable<Future<T>> visitDependencies<T>(
    Future<T> Function(Repository repo) callback,
  ) {
    return dependencies.values.map<Future<T>>((Repository repo) async {
      // Ensure this dep is sync'd with [this].
      await repo.sync(this);
      return callback(repo);
    });
  }

  final String name;

  Future<String> getVersion();

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

  late final Future<void> _ensureToolBuilt = startProcess(
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
          dependencies: const {}, // TODO
          name: 'engine',
        );

  Future<String> getVersion() async {
    final io.ProcessResult result = await runProcess(
      <String>['git', 'rev-parse', 'HEAD'],
      workingDirectory: dir.path,
    );

    if (result.exitCode != 0) {
      throw result;
    }

    return (result.stdout as String).trim();
  }

  Future<void> sync(covariant Framework parent) async {
    final revision = (await parent.dir
            .childDirectory('bin')
            .childDirectory('internal')
            .childFile('engine.version')
            .readAsString())
        .trim();

    await runProcess(<String>['git', 'checkout', revision], workingDirectory: dir.path);
  }
}
