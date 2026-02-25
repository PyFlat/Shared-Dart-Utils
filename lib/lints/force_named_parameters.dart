import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

class ForceNamedParameters extends AnalysisRule {
  static const LintCode code = LintCode(
    'force_named_parameters',
    'Too many positional parameters ({0}).',
    correctionMessage:
        "Use named parameters when there are more than one positional parameter.",
  );

  ForceNamedParameters()
    : super(
        name: 'force_named_parameters',
        description:
            'Enforce the use of named parameters when there are more than one positional parameter.',
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

    final positionalParams = parameterList.parameters
        .where((p) => p.isPositional)
        .toList();

    if (positionalParams.length > 1) {
      rule.reportAtNode(
        parameterList,
        arguments: [positionalParams.length.toString()],
      );
    }
  }
}
