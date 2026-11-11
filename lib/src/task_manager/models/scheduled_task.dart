import 'dart:async';

import 'task_context.dart';

enum TaskMode { main, isolate }

class ScheduledTask<TContext extends TaskContext> {
  final String name;
  final Duration interval;
  final bool noPrint;
  final bool skipIfRunning;
  final bool requiresContext;
  final TaskMode mode;
  final bool runImmediately;
  final FutureOr<dynamic> Function()? task;
  final FutureOr<dynamic> Function(TContext context)? contextTask;
  Timer? timer;

  ScheduledTask(
    this.name,
    this.interval,
    FutureOr<dynamic> Function() this.task, {
    this.noPrint = false,
    this.skipIfRunning = false,
    this.mode = TaskMode.main,
    this.runImmediately = false,
  }) : requiresContext = false,
       contextTask = null;

  ScheduledTask.withContext(
    this.name,
    this.interval,
    FutureOr<dynamic> Function(TContext context) this.contextTask, {
    this.noPrint = false,
    this.skipIfRunning = false,
    this.mode = TaskMode.main,
    this.runImmediately = false,
  }) : requiresContext = true,
       task = null;
}
