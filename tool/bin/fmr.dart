import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:fmr/fmr.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<int>(
    'fmr',
    'Flutter Mono-Repo Tool',
  )
    ..addCommand(SyncCommand())
    ..addCommand(StatusCommand(root: _root));

  // This can be null if no sub-command passed/parsed
  final int? code = (await runner.run(args));

  io.exit(code ?? 0);
}

const fs = LocalFileSystem();

Directory get _root => fs.file(io.Platform.script.path).parent.parent.parent;
