import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;

  Logger? _logger;

  LoggerService._internal();

  Future<void> init() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final logDir = Directory(p.join(directory.path, 'logs'));
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      final logFile = File(p.join(logDir.path, 'upscayl.log'));

      _logger = Logger(
        filter: ProductionFilter(),
        printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: false,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.dateAndTime,
        ),
        output: MultiOutput([
          ConsoleOutput(),
          FileOutput(file: logFile),
        ]),
      );

      _logger?.i('Logger initialized at ${logFile.path}');
    } catch (e) {
      // Fallback if path provider fails
      print('Failed to initialize local file logger: $e');
      _logger = Logger(
        printer: PrettyPrinter(),
      );
    }
  }

  void d(dynamic message) => _logger?.d(message);
  void i(dynamic message) => _logger?.i(message);
  void w(dynamic message) => _logger?.w(message);
  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) => _logger?.e(message, error: error, stackTrace: stackTrace);
}
