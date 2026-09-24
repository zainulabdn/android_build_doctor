import 'dart:async';
import 'dart:io';

import 'package:android_build_doctor/src/commands/runner.dart';

Future<void> main(List<String> args) async {
  // When output is piped into `head` or a closed pager, stdout reports
  // EPIPE (errno 32). That is not a tool failure; exit quietly.
  unawaited(stdout.done.catchError((Object _) {}));
  await runZonedGuarded(
    () async {
      final code = await AndroidBuildDoctorRunner().run(args);
      try {
        await stdout.flush();
      } on Object {
        // stdout already closed.
      }
      exit(code);
    },
    (error, stack) {
      if (error is FileSystemException && error.osError?.errorCode == 32) {
        exit(0);
      }
      stderr.writeln('android_build_doctor: unexpected error: $error');
      stderr.writeln(stack);
      exit(2);
    },
  );
}
