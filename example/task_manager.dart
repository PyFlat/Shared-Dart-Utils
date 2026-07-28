import 'package:pyflat_shared_utils/pyflat_shared_utils.dart';

class AuthContext extends TaskContext {
  final String accessToken;

  AuthContext(this.accessToken);

  @override
  Map<String, dynamic> toJson() => {'accessToken': accessToken};

  static AuthContext fromJson(Map<String, dynamic> json) =>
      AuthContext(json['accessToken'] as String);
}

Future<AuthContext> fetchAuthContext() async {
  return AuthContext('token-abc123');
}

final logService = LogService('taskManager');
final logger = Logger(services: [logService], writeToFile: false);
final taskLogger = ServiceLogger(logger, logService);

Future<void> main() async {
  final manager = TaskManager<AuthContext>(
    contextProvider: fetchAuthContext,
    contextFromJson: AuthContext.fromJson,
    logger: taskLogger,
  );

  manager.registerTask(
    ScheduledTask<AuthContext>('heartbeat', const Duration(seconds: 2), () {
      return 'ok';
    }),
    onSuccess: (result) => taskLogger.debug('heartbeat: $result'),
  );

  manager.registerTask(
    ScheduledTask<AuthContext>.withContext(
      'syncData',
      const Duration(seconds: 4),
      (AuthContext ctx) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return 'synced with token ${ctx.accessToken}';
      },
    ),
    mode: TaskMode.isolate,
    runImmediately: true,
    onSuccess: (result) => taskLogger.info('syncData: $result'),
  );

  manager.runTaskImmediately(
    task: () => 'one-off done',
    onSuccess: (result) => taskLogger.info('one-off: $result'),
  );

  manager.runTaskImmediatelyWithContext(
    task: (AuthContext ctx) => 'one-off with token ${ctx.accessToken}',
    mode: TaskMode.isolate,
    onSuccess: (result) => taskLogger.info('one-off with context: $result'),
  );

  await Future.delayed(const Duration(seconds: 6));
  manager.dispose();
}
