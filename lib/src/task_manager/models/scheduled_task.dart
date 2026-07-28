import 'dart:async';

import 'task_context.dart';

class ScheduledTask<TContext extends TaskContext> {
  final String name;
  final Duration interval;
  final bool noPrint;
  final bool requiresContext;
  final FutureOr<dynamic> Function()? task;
  final FutureOr<dynamic> Function(TContext context)? contextTask;
  Timer? timer;

  ScheduledTask(
    this.name,
    this.interval,
    FutureOr<dynamic> Function() this.task, {
    this.noPrint = false,
  }) : requiresContext = false,
       contextTask = null;

  ScheduledTask.withContext(
    this.name,
    this.interval,
    FutureOr<dynamic> Function(TContext context) this.contextTask, {
    this.noPrint = false,
  }) : requiresContext = true,
       task = null;
}
