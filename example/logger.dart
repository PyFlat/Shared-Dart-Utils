import 'package:shared_utils/shared_utils.dart';

part 'logger.service_logger.g.dart';

@logServices
class Services {
  static LogService app = LogService('app');
  static LogService api = LogService('api');
  static LogService db = LogService('database');

  static String xyz = 'not a log service';
}

final logger = Logger(
  services: [Services.app, Services.api, Services.db],
  writeToFile: true,
  printTimestamp: false,
  onlyKeepLastLogFiles: 5,
);

void main() {
  logger.app.info(
    "Application started",
    style: LogStyle.bold + LogStyle.blue + LogStyle.italic,
  );
  logger.app.debug("Debugging application");
  logger.api.info("Fetching data from API");
  logger.db.warn("Database connection is slow");
  logger.app.error("Unhandled exception occurred");
  logger.api.critical("API service is down");
}
