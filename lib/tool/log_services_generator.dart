import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';

class LogServices {
  const LogServices();
}

const logServices = LogServices();

Builder logServicesBuilder(BuilderOptions options) =>
    PartBuilder([LogServicesGenerator()], '.service_logger.g.dart');

class LogServicesGenerator extends Generator {
  static final _logServicesChecker = TypeChecker.typeNamed(LogServices);

  @override
  String generate(LibraryReader library, BuildStep buildStep) {
    final buffer = StringBuffer();

    for (final clazz in library.classes) {
      if (!_logServicesChecker.hasAnnotationOf(clazz)) continue;

      final fields = clazz.fields.where((f) {
        return f.isStatic && f.type.getDisplayString() == 'LogService';
      });

      buffer.writeln('extension ${clazz.name}LoggerExtension on Logger {');

      for (final field in fields) {
        buffer.writeln(
          '  ServiceLogger get ${field.name} => '
          'ServiceLogger(this, ${clazz.name}.${field.name});',
        );
      }

      buffer.writeln('}');
    }

    return buffer.toString();
  }
}
