import 'dart:async';

import 'repository.dart';

/// A recursive tree walker that ensures children are sync'd to their parent
/// before visiting.
Future<void> walkRepos<T>(
  Repository root,
  Future<void> Function(Repository repo, int depth) visit, {
  int depth = 0,
}) async {
  await visit(root, depth);
  final futures = root.dependencies.values.map<Future<void>>((Repository repo) async {
    await repo.sync(root);
    await walkRepos(repo, visit, depth: depth + 1);
  });

  await Future.wait(futures);
}
