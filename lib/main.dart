import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:pyflat_shared_utils/fixes/avoid_ambiguous_positional_parameters_fix.dart';
import 'lints/avoid_ambiguous_positional_parameters.dart';

final plugin = SharedUtilsPlugin();

class SharedUtilsPlugin extends Plugin {
  @override
  String get name => 'pyflat_shared_utils';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(AvoidAmbiguousPositionalParameters());
    registry.registerFixForRule(
      AvoidAmbiguousPositionalParameters.code,
      ConvertToNamedParameters.new,
    );
  }
}
