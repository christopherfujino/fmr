import 'dart:async';
import 'dart:io' as io;
import 'dart:convert';

import 'package:file/file.dart';

import 'pubspec.dart';
import 'utils.dart';

sealed class Repository {
  const Repository({
    this.dependencies = const <Repository>[],
    required this.name,
  });

  // TODO consider dependencies (such as pub packages) that appear multiple
  // times in the dependency graph.
  // TODO consider dependencies that were added (or removed) at a certain
  // point in time. [dependencies] may need to be lazily evaluated, dependent
  // on the version of the parent.
  final List<Repository> dependencies;

  Future<void> visitDependencies<T>(
    void Function(Repository repo) callback,
  ) async {
    for (final dependency in dependencies) {
      await dependency.sync(this);
      callback(dependency);
    }
  }

  // TODO add label for how it is pinned by its parent

  final String name;

  Future<String> getVersion();
  Future<String> getRevision();

  Future<void> sync(Repository parent);
}

/// A repository that is depended on via pinned git revision.
abstract class LocalRepository extends Repository {
  LocalRepository({
    super.dependencies,
    required super.name,
    required this.dir,
  }) : super();

  final Directory dir;

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
}

/// A package depended on via a pubspec.yaml file.
class PubDependency extends Repository {
  PubDependency({
    required super.name,
    required this.parentPubspec,
  }) : super();

  final Pubspec parentPubspec;

  Future<String> getRevision() async => 'unknown revision';

  Future<String> getVersion() async {
    return parentPubspec.dependencies[name]!;
  }

  // There is currently nothing to sync.
  // TODO we could curl the tarball from pub
  Future<void> sync(Repository parent) => Future<void>.value();
}

final class FlutterSDK extends LocalRepository {
  FlutterSDK({
    required Directory root,
  }) : super(
          dependencies: [
            Engine(root: root),
            FlutterTools(root: root),
          ],
          name: 'Flutter SDK',
          dir: root.childDirectory('framework'),
        );

  File get flutterBin => dir.childDirectory('bin').childFile('flutter');

  Future<void> get _ensureToolBuilt => runProcess(
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
    throw UnimplementedError(
        'The Flutter SDK is the root--there is no parent!');
  }
}

final class FlutterTools extends LocalRepository {
  FlutterTools({required Directory root})
      : super(
          name: 'flutter_tools',
          dependencies: _dependenciesFromPubspec(
            root
                .childDirectory('framework')
                .childDirectory('packages')
                .childDirectory('flutter_tools')
                .childFile('pubspec.yaml'),
          ),
          dir: root
              .childDirectory('framework')
              .childDirectory('packages')
              .childDirectory('flutter_tools'),
        );

  Future<String> getVersion() =>
      Future<String>.value('n/a (same as framework)');

  // no-op.
  Future<void> sync(covariant FlutterSDK parent) async {}
}

final class Engine extends LocalRepository {
  Engine({
    required Directory root,
  }) : super(
          dir: root.childDirectory('engine'),
          dependencies: [DartSDK(root: root)],
          name: 'engine',
        );

  Future<String> getVersion() => getRevision();

  Future<void> sync(covariant FlutterSDK parent) async {
    final revision = (await parent.dir
            .childDirectory('bin')
            .childDirectory('internal')
            .childFile('engine.version')
            .readAsString())
        .trim();

    await _checkoutWithoutHooks(revision, dir);
  }
}

//final class BuildRoot extends LocalRepository {
//  BuildRoot({
//    required Directory root,
//  }) : super(
//          name: 'buildroot',
//        );
//}

/// Dart SDK monorepo.
///
/// Fetched from https://github.com/dart-lang/sdk.
final class DartSDK extends LocalRepository {
  DartSDK({
    required Directory root,
  }) : super(
          dir: root.childDirectory('dart-sdk'),
          dependencies: [AnalysisServer(root: root)],
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

    await _checkoutWithoutHooks(revision, dir);
  }
}

// Part of Dart repo.
final class AnalysisServer extends LocalRepository with PubPackage {
  AnalysisServer({
    required Directory root,
  }) : super(
          dir: root
              .childDirectory('dart-sdk')
              .childDirectory('pkg')
              .childDirectory('analysis_server'),
          dependencies: [UnifiedAnalytics(root: root)],
          name: 'analysis_server',
        );

  // no-op, part of parent's monorepo.
  Future<void> sync(covariant DartSDK parent) async {}
}

final class UnifiedAnalytics extends LocalRepository with PubPackage {
  UnifiedAnalytics({
    required Directory root,
  }) : super(
          dir: root
              .childDirectory('dart-tools')
              .childDirectory('pkgs')
              .childDirectory('unified_analytics'),
          dependencies: _dependenciesFromPubspec(
            root
                .childDirectory('dart-tools')
                .childDirectory('pkgs')
                .childDirectory('unified_analytics')
                .childFile('pubspec.yaml'),
          ),
          name: 'unified_analytics',
        );

  static final _kToolsRevDartDepsPattern =
      RegExp(r'\s+"tools_rev": "([\da-f]{40})",');
  Future<void> sync(Repository parent) async {
    switch (parent) {
      case AnalysisServer():
        // parent.dir will be //sdk/pkg/analyzer
        final depsFile = parent.dir.parent.parent.childFile('DEPS');
        final deps = (await depsFile.readAsString()).trim();

        final match = _kToolsRevDartDepsPattern.firstMatch(deps);
        if (match == null) {
          throw DependencyDoesNotExist(
            child: this,
            parent: parent,
          );
        }

        final revision = match.group(1)!;

        await _checkoutWithoutHooks(revision, dir);
      default:
        throw UnimplementedError(
            "Don't know how to sync $name to ${parent.name}");
    }
  }
}

mixin PubPackage on LocalRepository {
  Future<String> getVersion() async {
    final pubspec = Pubspec.fromFile(dir.childFile('pubspec.yaml'));
    // get first 8 chars
    final revision = (await getRevision()).substring(0, 9);
    final pubspecVersion = pubspec.version;
    if (pubspecVersion == null) {
      return 'no pubspec version ($revision)';
    }
    // question mark because reading version from pubspec may not be correct
    // if this commit is not a release.
    return '${pubspec.version}? ($revision)';
  }
}

List<Repository> _dependenciesFromPubspec(File pubspecFile) {
  final pubspec = Pubspec.fromFile(pubspecFile);
  return pubspec.dependencies.keys.map<Repository>((String name) {
    return PubDependency(
      name: name,
      parentPubspec: pubspec,
    );
  }).toList();
}

Future<void> _checkoutWithoutHooks(String ref, Directory dir) async {
  await runProcess(
    <String>[
      'git',
      '-c',
      // won't work on Windows
      'core.hooksPath=/dev/null',
      'fetch',
      '--all',
    ],
    workingDirectory: dir.path,
  );
  await runProcess(
    <String>[
      'git',
      '-c',
      // won't work on Windows
      'core.hooksPath=/dev/null',
      'checkout',
      ref,
    ],
    workingDirectory: dir.path,
  );
}

final class DependencyDoesNotExist implements Exception {
  DependencyDoesNotExist({
    required this.child,
    required this.parent,
  });

  final Repository child;
  final Repository parent;
}
