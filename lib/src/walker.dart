import 'repository.dart';

Future<List<T>> walkRepos<T>(
  Repository root,
  Future<T> Function(Repository repo) callback,
) async {
  return Future.wait(<Future<T>>[
    callback(root),
    ...root.visitDependencies<T>((Repository repo) {
      return walkRepos(repo, callback);
    }),
  ]);
}
