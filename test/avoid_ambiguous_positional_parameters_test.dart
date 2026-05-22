// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:pyflat_shared_utils/lints/avoid_ambiguous_positional_parameters.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ForceNamedParametersTest);
  });
}

@reflectiveTest
class ForceNamedParametersTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidAmbiguousPositionalParameters();
    super.setUp();
  }

  void test_different_types() async {
    await assertNoDiagnostics(r'''
      void f(int a, String b) {}
    ''');
  }

  void test_duplicate_types() async {
    await assertDiagnostics(r'''void f(int a, int b) {}''', [lint(6, 14)]);
  }

  void test_mixed_parameters() async {
    await assertDiagnostics(
      r'''void f(int a, String b, int c) {}''',
      [lint(6, 24)],
    );
  }

  void test_duplicate_types_with_named_parameters() async {
    await assertDiagnostics(
      r'''void f(int a, int b, {int? c}) {}''',
      [lint(6, 24)],
    );
  }

  void test_named_parameters_ignored() async {
    await assertNoDiagnostics(r'''
      void f({int? a, int? b}) {}
    ''');
  }

  void test_mixed_parameters_ignored_if_positional_are_different() async {
    await assertNoDiagnostics(r'''
      void f(int a, {int? b}) {}
    ''');
  }

  void test_empty_parameters() async {
    await assertNoDiagnostics(r'''
      void f() {}
    ''');
  }

  void test_untypedParameters() async {
    await assertDiagnostics(r'''void f(a, b) {}''', [lint(6, 6)]);
  }

  void test_optionalPositional() async {
    await assertDiagnostics(
      r'''void f([int a = 0, int? b]) {}''',
      [lint(6, 21)],
    );
  }

  void test_mixedRequiredAndOptionalPositional() async {
    await assertDiagnostics(r'''void f(int a, [int? b]) {}''', [lint(6, 17)]);
  }

  void test_generics() async {
    await assertDiagnostics(
      r'''void f(List<String> a, List<String> b) {}''',
      [lint(6, 32)],
    );
  }
}
