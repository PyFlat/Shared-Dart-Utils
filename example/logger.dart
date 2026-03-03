import 'package:pyflat_shared_utils/pyflat_shared_utils.dart';

part 'logger.service_logger.g.dart';

@logServices
class Services {
  static LogService app = LogService('app');
  static LogService api = LogService('api');
  static LogService db = LogService('database');

  static String xyz = 'not a log service';
}

final logger = Logger(
  services: allServices,
  writeToFile: true,
  printTimestamp: false,
  onlyKeepLastLogFiles: 1,
);

void main() async {
  logger.app.info(
    "Application started",
    style: LogStyle.bold + LogStyle.blue + LogStyle.italic,
  );
  logger.app.debug("Debugging application");
  logger.api
      .timed('Fetching more data', () async {
        await Future.delayed(Duration(seconds: 10));
        return 'More data fetched';
      })
      .then((result) {
        logger.api.info(result);
      });

  logger.api.timed('Fetching data from API', () async {
    await Future.delayed(Duration(seconds: 5));
    return 'Data fetched';
  });

  logger.db.warn("Database connection is slow");
  logger.app.error("Unhandled exception occurred");

  logger.api.critical("API service is down");
}
