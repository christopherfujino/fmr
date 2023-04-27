import 'dart:async';

import 'repository.dart';

/// A recursive tree walker that ensures children are sync'd to their parent
/// before visiting.
///
/// Yields a [Node<T>], which is the root of a tree of T values.
Future<Node<T>> mapRepos<T>(
  Repository root,
  Future<T> Function(Repository repo) map,
) async {
  final value = await map(root);
  final futures = root.dependencies.map<Future<Node<T>>>((Repository repo) async {
    await repo.sync(root);
    return await mapRepos(repo, map);
  });

  return Node(
    children: await Future.wait(futures),
    value: value,
  );
}

class Node<T> {
  Node({
    Iterable<Node<T>>? children,
    required this.value,
  }) : children = children ?? <Node<T>>[];

  final Iterable<Node<T>> children;
  final T value;
}
