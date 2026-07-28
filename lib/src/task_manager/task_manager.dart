import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import '../logger.dart';
import 'models/scheduled_task.dart';
import 'models/task_context.dart';
import 'models/task_result.dart';

enum TaskMode { main, isolate }

class _TaskWorkRequest<TContext extends TaskContext> {
  final String name;
  final bool noPrint;
  final FutureOr<dynamic> Function()? task;
  final FutureOr<dynamic> Function(TContext context)? contextTask;
  final Map<String, dynamic>? contextJson;
  final TContext Function(Map<String, dynamic> json)? contextFromJson;

  _TaskWorkRequest({
    required this.name,
    required this.noPrint,
    this.task,
    this.contextTask,
    this.contextJson,
    this.contextFromJson,
  });
}

class _WorkerState {
  final int id;
  final SendPort sendPort;
  bool isBusy = false;

  _WorkerState({required this.id, required this.sendPort});
}

class TaskManager<TContext extends TaskContext> {
  final FutureOr<TContext> Function()? contextProvider;
  final TContext Function(Map<String, dynamic> json)? contextFromJson;

  final ReceivePort _mainReceivePort = ReceivePort();
  final Map<String, Timer> _timers = {};
  final Map<String, Function(dynamic)> _callbacks = {};
  final Map<String, Completer<dynamic>> _activeIsolateTasks = {};

  final ServiceLogger? _logger;
  final int _poolSize;
  final List<_WorkerState> _workers = [];
  final List<Isolate> _isolates = [];
  final Queue<_TaskWorkRequest<TContext>> _taskQueue = Queue();
  final Completer<void> _workerPoolReady = Completer<void>();

  TaskManager({
    this.contextProvider,
    this.contextFromJson,
    this._logger,
    this._poolSize = 3,
  }) : assert(
         (contextProvider == null) == (contextFromJson == null),
         'contextProvider and contextFromJson must be provided together',
       ) {
    _initWorker();
    _listenToResults();
  }

  Future<T> _timed<T>(
    String message,
    Future<T> Function() body, {
    bool noPrint = false,
  }) {
    final logger = _logger;
    if (logger == null) return body();
    return logger.timed(message, body, level: LogLevel.debug, noPrint: noPrint);
  }

  Future<void> _initWorker() async {
    for (int i = 0; i < _poolSize; i++) {
      final initPort = RawReceivePort();

      initPort.handler = (dynamic message) {
        if (message is SendPort) {
          _workers.add(_WorkerState(id: i, sendPort: message));
          initPort.close();
          if (_workers.length == _poolSize && !_workerPoolReady.isCompleted) {
            _workerPoolReady.complete();
            _logger?.info(
              'Persistent Worker Pool initialized with $_poolSize isolates',
            );
          }
        }
      };

      final isolate = await Isolate.spawn(_persistentWorkerLoop<TContext>, {
        'workerId': i,
        'initPort': initPort.sendPort,
        'resultPort': _mainReceivePort.sendPort,
      });
      _isolates.add(isolate);
    }
  }

  void _listenToResults() {
    _mainReceivePort.listen((message) {
      if (message is TaskResult) {
        if (_activeIsolateTasks.containsKey(message.taskName)) {
          final completer = _activeIsolateTasks.remove(message.taskName)!;
          if (message.success) {
            completer.complete(message.result);
          } else {
            completer.completeError(message.error ?? 'Unknown error');
          }
        }
        if (message.success) {
          if (_callbacks.containsKey(message.taskName)) {
            _callbacks[message.taskName]!(message.result);
          }
        } else {
          _logger?.error('Task "${message.taskName}" failed: ${message.error}');
        }
        if (message.workerId != -1) {
          _WorkerState? finishedWorker;
          for (var worker in _workers) {
            if (worker.id == message.workerId) {
              finishedWorker = worker;
              break;
            }
          }
          if (finishedWorker != null) {
            finishedWorker.isBusy = false;

            if (_taskQueue.isNotEmpty) {
              final nextTask = _taskQueue.removeFirst();
              finishedWorker.isBusy = true;
              finishedWorker.sendPort.send(nextTask);
            }
          }
        }
      }
    });
  }

  void registerTask(
    ScheduledTask<TContext> task, {
    TaskMode mode = TaskMode.main,
    bool runImmediately = false,
    Function(dynamic)? onSuccess,
  }) {
    if (_timers.containsKey(task.name)) {
      throw Exception('Task "${task.name}" already exists');
    }
    _checkContextConfigured(task);

    if (onSuccess != null) {
      _callbacks[task.name] = onSuccess;
    }

    _timers[task.name] = Timer.periodic(task.interval, (_) {
      mode == TaskMode.main ? _runInMain(task) : _runInCpu(task);
    });

    if (runImmediately) {
      mode == TaskMode.main ? _runInMain(task) : _runInCpu(task);
    }

    _logger?.info(
      'Registered task "${task.name}" every ${task.interval.inSeconds}s (mode: $mode)',
    );
  }

  void unregisterTask(String name) {
    final timer = _timers.remove(name);
    if (timer != null) {
      timer.cancel();
      _logger?.info('Unregistered task "$name"');
    }
  }

  void runTaskImmediately({
    required FutureOr<dynamic> Function() task,
    TaskMode mode = TaskMode.main,
    Function(dynamic)? onSuccess,
  }) {
    final taskName = 'immediateTask_${DateTime.now().millisecondsSinceEpoch}';

    if (onSuccess != null) {
      _callbacks[taskName] = onSuccess;
    }

    final tempTask = ScheduledTask<TContext>(taskName, Duration.zero, task);
    mode == TaskMode.main ? _runInMain(tempTask) : _runInCpu(tempTask);
  }

  void runTaskImmediatelyWithContext({
    required FutureOr<dynamic> Function(TContext context) task,
    TaskMode mode = TaskMode.main,
    Function(dynamic)? onSuccess,
  }) {
    final taskName = 'immediateTask_${DateTime.now().millisecondsSinceEpoch}';

    if (onSuccess != null) {
      _callbacks[taskName] = onSuccess;
    }

    final tempTask = ScheduledTask<TContext>.withContext(
      taskName,
      Duration.zero,
      task,
    );
    mode == TaskMode.main ? _runInMain(tempTask) : _runInCpu(tempTask);
  }

  void _checkContextConfigured(ScheduledTask<TContext> task) {
    if (task.requiresContext && contextProvider == null) {
      throw ArgumentError(
        'Task "${task.name}" requires a context, but this TaskManager was '
        'not configured with a contextProvider.',
      );
    }
  }

  void _runInMain(ScheduledTask<TContext> task) async {
    final stopwatch = Stopwatch()..start();
    try {
      TContext? context;
      if (task.requiresContext) {
        context = await contextProvider!();
      }

      final result = await _timed(
        "${"[Main]".padRight("[Isolate]".length)}Running task ${task.name}",
        () async => task.requiresContext
            ? await task.contextTask!(context as TContext)
            : await task.task!(),
        noPrint: task.noPrint,
      );
      _mainReceivePort.sendPort.send(
        TaskResult(
          taskName: task.name,
          success: true,
          result: result,
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
          noPrint: task.noPrint,
        ),
      );
    } catch (e, st) {
      _mainReceivePort.sendPort.send(
        TaskResult(
          taskName: task.name,
          success: false,
          error: '$e\n$st',
          elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        ),
      );
    }
  }

  void _runInCpu(ScheduledTask<TContext> task) async {
    await _workerPoolReady.future;

    Map<String, dynamic>? contextJson;
    if (task.requiresContext) {
      final context = await contextProvider!();
      contextJson = context.toJson();
    }

    final completer = Completer<dynamic>();
    _activeIsolateTasks[task.name] = completer;

    try {
      await _timed("[Isolate]Running task ${task.name}", () async {
        final request = _TaskWorkRequest<TContext>(
          name: task.name,
          noPrint: task.noPrint,
          task: task.task,
          contextTask: task.contextTask,
          contextJson: contextJson,
          contextFromJson: contextFromJson,
        );

        _WorkerState? idleWorker;
        for (var worker in _workers) {
          if (!worker.isBusy) {
            idleWorker = worker;
            break;
          }
        }

        if (idleWorker != null) {
          idleWorker.isBusy = true;
          idleWorker.sendPort.send(request);
        } else {
          _taskQueue.add(request);
        }

        return await completer.future;
      });
    } catch (_) {}
  }

  void dispose() {
    for (var timer in _timers.values) {
      timer.cancel();
    }

    _timers.clear();
    _taskQueue.clear();

    for (var isolate in _isolates) {
      isolate.kill(priority: Isolate.immediate);
    }

    _isolates.clear();
    _workers.clear();

    _mainReceivePort.close();

    _logger?.info('Disposed TaskManager and killed all worker isolates');
  }
}

void _persistentWorkerLoop<TContext extends TaskContext>(
  Map<String, dynamic> initData,
) async {
  final int workerId = initData['workerId'];
  final SendPort initPort = initData['initPort'];
  final SendPort resultPort = initData['resultPort'];

  final workerReceivePort = ReceivePort();
  initPort.send(workerReceivePort.sendPort);

  await for (final message in workerReceivePort) {
    if (message is _TaskWorkRequest<TContext>) {
      final stopwatch = Stopwatch()..start();
      try {
        final dynamic result;

        if (message.contextJson != null) {
          final context = message.contextFromJson!(message.contextJson!);
          result = await message.contextTask!(context);
        } else {
          result = await message.task!();
        }

        stopwatch.stop();
        resultPort.send(
          TaskResult(
            taskName: message.name,
            success: true,
            result: result,
            elapsedMilliseconds: stopwatch.elapsedMilliseconds,
            noPrint: message.noPrint,
            workerId: workerId,
          ),
        );
      } catch (e, st) {
        stopwatch.stop();
        resultPort.send(
          TaskResult(
            taskName: message.name,
            success: false,
            error: '$e\n$st',
            elapsedMilliseconds: stopwatch.elapsedMilliseconds,
            workerId: workerId,
          ),
        );
      }
    }
  }
}
