// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'logger.dart';

// **************************************************************************
// LogServicesGenerator
// **************************************************************************

extension ServicesLoggerExtension on Logger {
  ServiceLogger get app => ServiceLogger(this, Services.app);
  ServiceLogger get api => ServiceLogger(this, Services.api);
  ServiceLogger get db => ServiceLogger(this, Services.db);
}

final List<LogService> allServices = [Services.app, Services.api, Services.db];
