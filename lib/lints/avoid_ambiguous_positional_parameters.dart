import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class AvoidAmbiguousPositionalParameters extends AnalysisRule {
  static const LintCode code = LintCode(
    'avoid_ambiguous_positional_parameters',
    'Multiple positional parameters share the same type ({0}).',
    correctionMessage:
        "Use named parameters when there are more than one positional parameter.",
  );

  AvoidAmbiguousPositionalParameters()
    : super(
        name: 'avoid_ambiguous_positional_parameters',
        description:
            'Avoid multiple positional parameters with the same type to prevent ambiguity at the call site.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this, context);
    registry.addMethodDeclaration(this, visitor);
    registry.addFunctionDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _checkParameters(node.parameters);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _checkParameters(node.functionExpression.parameters);
  }

  void _checkParameters(FormalParameterList? parameterList) {
    if (parameterList == null) return;

    final positionalParams = parameterList.parameters.where(
      (p) => p.isPositional,
    );
    final seenTypes = <String>{};

    for (final param in positionalParams) {
      final element = param.declaredFragment?.element;

      String typeString = element?.type.getDisplayString() ?? 'dynamic';

      if (typeString.endsWith('?')) {
        typeString = typeString.substring(0, typeString.length - 1);
      }

      if (!seenTypes.add(typeString)) {
        rule.reportAtNode(parameterList, arguments: [typeString]);
        return;
      }
    }
  }
}
