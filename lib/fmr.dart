import 'package:args/command_runner.dart';
import 'src/utils.dart';

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
