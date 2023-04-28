import 'dart:io' as io;

Future<int> startProcess(
  List<String> cmd, {
  bool requireSuccess = true,
  bool verbose = false,
  String? workingDirectory,
}) async {
  if (verbose) {
    var message = 'Executing `$cmd`';
    if (workingDirectory != null) {
      message += ' in $workingDirectory';
    }
    print(message);
  }
  final executable = cmd.first;
  final args = cmd.sublist(1);
  final process = await io.Process.start(
    executable,
    args,
    mode:
        verbose ? io.ProcessStartMode.inheritStdio : io.ProcessStartMode.normal,
    workingDirectory: workingDirectory,
  );
  final exitCode = await process.exitCode;
  if (requireSuccess && exitCode != 0) {
    throw io.ProcessException(
      executable,
      args,
      'Returned non-zero: $exitCode (in $workingDirectory)',
      exitCode,
    );
  }
  return exitCode;
}

Future<io.ProcessResult> runProcess(
  List<String> cmd, {
  bool requireSuccess = true,
  bool verbose = false,
  String? workingDirectory,
}) async {
  if (verbose) {
    var message = 'Executing `$cmd`';
    if (workingDirectory != null) {
      message += ' in $workingDirectory';
    }
    print(message);
  }
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
      'Returned non-zero: $exitCode (in $workingDirectory)\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
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
