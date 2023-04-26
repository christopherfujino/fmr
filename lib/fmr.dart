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
    final framework = Framework(root: root);

    final versions = await walkRepos<String>(
      framework,
      (Repository repo) async {
        return '${repo.name}: '.padRight(10) + await repo.getVersion();
      },
    );
    for (final version in versions) {
      print(version);
    }

    return 0;
  }
}
