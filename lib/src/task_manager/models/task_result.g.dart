// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskResult _$TaskResultFromJson(Map<String, dynamic> json) => TaskResult(
  taskName: json['taskName'] as String,
  success: json['success'] as bool,
  result: json['result'],
  error: json['error'],
  elapsedMilliseconds: (json['elapsedMilliseconds'] as num).toInt(),
  noPrint: json['noPrint'] as bool? ?? false,
  workerId: (json['workerId'] as num?)?.toInt() ?? -1,
);

Map<String, dynamic> _$TaskResultToJson(TaskResult instance) =>
    <String, dynamic>{
      'taskName': instance.taskName,
      'success': instance.success,
      'result': instance.result,
      'error': instance.error,
      'elapsedMilliseconds': instance.elapsedMilliseconds,
      'noPrint': instance.noPrint,
      'workerId': instance.workerId,
    };
