import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

class ConvertToNamedParameters extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'pyflat_shared_utils.fix.convertToNamed',
    DartFixKindPriority.standard,
    "Convert to named parameters",
  );

  ConvertToNamedParameters({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final parameterList = node;

    if (parameterList is FormalParameterList) {
      final params = parameterList.parameters;
      if (params.isEmpty) return;

      await builder.addDartFileEdit(file, (fileBuilder) {
        fileBuilder.addReplacement(range.node(parameterList), (builder) {
          builder.write('({');

          for (var i = 0; i < params.length; i++) {
            final p = params[i];

            if (p.isPositional) {
              builder.write('required ');
            }

            builder.write(p.toSource());

            if (i < params.length - 1) {
              builder.write(', ');
            }
          }

          builder.write('})');
        });
      });
    }
  }
}
