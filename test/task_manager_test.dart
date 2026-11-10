import 'dart:async';

import 'package:pyflat_shared_utils/pyflat_shared_utils.dart';
import 'package:test/test.dart';

class _Ctx extends TaskContext {
  _Ctx(this.value);
  final String value;

  factory _Ctx.fromJson(Map<String, dynamic> json) =>
      _Ctx(json['value'] as String);

  @override
  Map<String, dynamic> toJson() => {'value': value};
}

class _Handled implements Exception {}

bool _handleMarked(String taskName, Object error, StackTrace stack) =>
    error is _Handled;

final _service = LogService('tasks');
final _logger = Logger(services: [_service], writeToFile: false);
final _log = ServiceLogger(_logger, _service);

Future<List<String>> _errorsWhile(Future<void> Function() body) async {
  final lines = <String>[];
  final sub = _logger.logStream
      .where((l) => l.contains('[ERROR]'))
      .listen(lines.add);
  await body();
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await sub.cancel();
  return lines;
}

void main() {
  group('onError', () {
    late TaskManager<_Ctx> manager;
    late List<String> seen;

    setUp(() {
      seen = [];
      manager = TaskManager<_Ctx>(
        onError: (name, error, stack) {
          seen.add(name);
          return error is _Handled;
        },
        logger: _log,
        poolSize: 1,
      );
    });

    tearDown(() => manager.dispose());

    test('handled errors are not logged', () async {
      final errors = await _errorsWhile(() async {
        manager.registerTask(
          ScheduledTask('handled', const Duration(hours: 1), () {
            throw _Handled();
          }),
          runImmediately: true,
        );
      });
      expect(seen, ['handled']);
      expect(errors, isEmpty);
    });

    test('unhandled errors are still logged with the stack trace', () async {
      final errors = await _errorsWhile(() async {
        manager.registerTask(
          ScheduledTask('broken', const Duration(hours: 1), () {
            throw StateError('boom');
          }),
          runImmediately: true,
        );
      });
      expect(seen, ['broken']);
      expect(errors, hasLength(1));
      expect(errors.single, contains('Task "broken" failed: Bad state: boom'));
      expect(errors.single, contains('task_manager_test.dart'));
    });
  });

  test('onError runs inside the worker for isolate tasks', () async {
    final manager = TaskManager<_Ctx>(
      onError: _handleMarked,
      logger: _log,
      poolSize: 1,
    );
    addTearDown(manager.dispose);

    final errors = await _errorsWhile(() async {
      manager.registerTask(
        ScheduledTask('isolateHandled', const Duration(hours: 1), () {
          throw _Handled();
        }),
        mode: TaskMode.isolate,
        runImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    expect(errors, isEmpty);
  });

  test('a failing context provider in isolate mode is caught', () async {
    final manager = TaskManager<_Ctx>(
      contextProvider: () => throw StateError('no token'),
      contextFromJson: _Ctx.fromJson,
      logger: _log,
      poolSize: 1,
    );
    addTearDown(manager.dispose);

    final errors = await _errorsWhile(() async {
      manager.registerTask(
        ScheduledTask<_Ctx>.withContext(
          'needsContext',
          const Duration(hours: 1),
          (_) {},
        ),
        mode: TaskMode.isolate,
        runImmediately: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(errors, hasLength(1));
    expect(errors.single, contains('Task "needsContext" failed'));
  });

  test('skipIfRunning skips runs while the previous one is active', () async {
    final manager = TaskManager<_Ctx>(logger: _log, poolSize: 1);
    addTearDown(manager.dispose);

    var started = 0;
    final release = Completer<void>();
    manager.registerTask(
      ScheduledTask('slow', const Duration(milliseconds: 20), () async {
        started++;
        await release.future;
      }, skipIfRunning: true),
      runImmediately: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(started, 1);

    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(started, greaterThan(1));
  });

  test('without skipIfRunning main tasks may overlap', () async {
    final manager = TaskManager<_Ctx>(logger: _log, poolSize: 1);
    addTearDown(manager.dispose);

    var started = 0;
    final release = Completer<void>();
    manager.registerTask(
      ScheduledTask('overlap', const Duration(milliseconds: 20), () async {
        started++;
        await release.future;
      }),
      runImmediately: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 150));
    release.complete();
    expect(started, greaterThan(1));
  });
}
