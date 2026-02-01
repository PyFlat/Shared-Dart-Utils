import 'package:shared_utils/shared_utils.dart';

extension Services on LogService {
  static LogService app = LogService('app');
  static LogService api = LogService('api');
  static LogService db = LogService('database');
}

final logger = Logger(
  services: [Services.app, Services.api, Services.db],
  writeToFile: true,
  printTimestamp: false,
  onlyKeepLastLogFiles: 5,
);

void main() {
  logger.start(Services.app, "Application started");
  logger.debug(Services.app, "Debugging application");
  logger.info(Services.api, "Fetching data from API");
  logger.warn(Services.db, "Database connection is slow");
  logger.error(Services.app, "Unhandled exception occurred");
  logger.critical(Services.api, "API service is down");
}
