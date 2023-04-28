import 'dart:async';
import 'dart:io' as io;

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
  List<Future<Node<T>>> futures = <Future<Node<T>>>[];
  try {
    for (final dependency in root.dependencies) {
      // Must use .then(onError: ...) in order to catch an async exception
      final maybeFuture = await dependency.sync(root).then<Future<Node<T>>?>(
        (void _) => mapRepos<T>(dependency, map),
        onError: (Object err, StackTrace _) {
          if (err is! DependencyDoesNotExist) {
            throw err;
          }
          io.stderr.writeln('${err.parent.name} does not have dependency ${err.child.name}');
          return null;
        },
      );
      if (maybeFuture != null) {
        futures.add(maybeFuture);
      }
    }
  } on DependencyDoesNotExist catch (exc) {
    io.stderr.writeln(
      'Failed to sync dependency ${exc.child.name} to ${exc.parent.name}',
    );
  }

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
