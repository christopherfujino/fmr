import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:fmr/fmr.dart';

void main() {
  final runner = CommandRunner<int>()
      ..addCommand();

  final int code = runner.run()!;
  exit(code);
}
