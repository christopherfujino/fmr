import 'repository.dart';

Future<List<T>> walkRepos<T>(
  Repository root,
  Future<T> Function(Repository repo) callback,
) async {
  return Future.wait([
    callback(root),
    ...root.visitDependencies<T>(callback),
  ]);
}
