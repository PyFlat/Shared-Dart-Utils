import 'package:json_annotation/json_annotation.dart';

part 'task_result.g.dart';

@JsonSerializable()
class TaskResult {
  final String taskName;
  final bool success;
  final dynamic result;
  final dynamic error;
  final int elapsedMilliseconds;
  final bool noPrint;
  final int workerId;

  TaskResult({
    required this.taskName,
    required this.success,
    this.result,
    this.error,
    required this.elapsedMilliseconds,
    this.noPrint = false,
    this.workerId = -1,
  });

  factory TaskResult.fromJson(Map<String, dynamic> json) =>
      _$TaskResultFromJson(json);

  Map<String, dynamic> toJson() => _$TaskResultToJson(this);
}
