import 'dart:io' as io;

Future<int> startProcess(
  List<String> cmd, {
  bool requireSuccess = true,
}) async {
  print('Executing `${cmd.join(' ')}`');
  final executable = cmd.first;
  final args = cmd.sublist(1);
  final process = await io.Process.start(
    executable,
    args,
    mode: io.ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (requireSuccess && exitCode != 0) {
    throw io.ProcessException(
      executable,
      args,
      'Returned non-zero',
      exitCode,
    );
  }
  return exitCode;
}

Future<io.ProcessResult> runProcess(
  List<String> cmd, {
  bool requireSuccess = true,
  String? workingDirectory,
}) async {
  print(
      'Executing `${cmd.join(' ')}`${workingDirectory == null ? '' : ' in $workingDirectory'}');
  final executable = cmd.first;
  final args = cmd.sublist(1);
  final result = await io.Process.run(
    executable,
    args,
    workingDirectory: workingDirectory,
  );
  final exitCode = result.exitCode;
  if (requireSuccess && exitCode != 0) {
    throw io.ProcessException(
      executable,
      args,
      'Returned non-zero',
      exitCode,
    );
  }
  return result;
}

Future<String> get python async {
  var result = await runProcess(
    <String>['which', 'python3'],
    requireSuccess: false,
  );
  if (result.exitCode == 0) {
    return (result.stdout as String).trim();
  }
  result = await runProcess(
    <String>['which', 'python'],
  );
  return (result.stdout as String).trim();
}
