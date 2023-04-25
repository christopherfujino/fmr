import 'dart:io' as io;

Future<int> startProcess(
  List<String> cmd, {
  bool requireSuccess = true,
}) async {
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
