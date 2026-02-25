import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:pyflat_shared_utils/fixes/force_named_parameters_fix.dart';
import 'lints/force_named_parameters.dart';

final plugin = SharedUtilsPlugin();

class SharedUtilsPlugin extends Plugin {
  @override
  String get name => 'pyflat_shared_utils';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(ForceNamedParameters());
    registry.registerFixForRule(
      ForceNamedParameters.code,
      ConvertToNamedParameters.new,
    );
  }
}
