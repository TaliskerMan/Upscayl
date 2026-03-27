import 'dart:io';
import 'dart:convert';
import 'logger_service.dart';

class UpscaylEngine {
  Process? _activeProcess;
  final LoggerService _logger = LoggerService();

  /// Executes Upscayl binary cleanly via native processes
  Stream<double> runUpscayl({
    required String inputPath,
    required String outputPath,
    required String modelName,
    bool useTTA = false,
  }) async* {
    if (inputPath.startsWith('-') || outputPath.startsWith('-')) {
      _logger.e('Invalid input or output path: Paths cannot start with a hyphen to prevent command injection.');
      throw Exception('Security Error: Invalid file path detected. Paths must not start with a hyphen.');
    }

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final flutterAssetsDir = '$exeDir/data/flutter_assets/assets';
    final upscaylBinPath = '$flutterAssetsDir/linux/bin/upscayl-bin';
    final modelsPath = '$flutterAssetsDir/models';

    _logger.i('==== UPSCAYL NATIVE EXECUTION ====');
    _logger.i('Executable Dir: $exeDir');
    _logger.i('Binary Path: $upscaylBinPath');
    _logger.i('Models Path: $modelsPath');
    _logger.i('Input: $inputPath');
    _logger.i('Output: $outputPath');
    _logger.i('Model Type: $modelName');
    _logger.i('TTA Enabled: $useTTA');

    // Ensure it's executable
    if (Platform.isLinux || Platform.isMacOS) {
      _logger.i('Making binary executable...');
      await Process.run('chmod', ['+x', upscaylBinPath]);
    }

    _logger.i('Spawning Subprocess...');
    
    final arguments = [
      '-i', inputPath,
      '-o', outputPath,
      '-n', modelName,
      '-s', '4', // Scale by default is 4
      '-m', modelsPath,
    ];
    
    if (useTTA) {
      arguments.add('-x');
    }

    _activeProcess = await Process.start(
      upscaylBinPath,
      arguments,
    );

    _logger.i('Process spawned with PID: ${_activeProcess!.pid}');

    // Realesrgan-ncnn-vulkan usually outputs progress to stderr, e.g., "12.34%"
    await for (final bytes in _activeProcess!.stderr) {
      final text = utf8.decode(bytes, allowMalformed: true);
      // _logger.d('STDERR: $text'); // Uncomment if we need extreme verbosity
      final lines = text.split('\n');
      for (final line in lines) {
        final match = RegExp(r'(\d+\.\d+)%').firstMatch(line);
        if (match != null) {
          final percentStr = match.group(1);
          if (percentStr != null) {
            final percent = double.tryParse(percentStr);
            if (percent != null) {
              yield percent / 100.0;
            }
          }
        }
      }
    }
    
    final exitCode = await _activeProcess!.exitCode;
    _activeProcess = null;
    _logger.i('Process Exited with Code: $exitCode');
    
    if (exitCode != 0) {
      _logger.e('Upscayl failed with exit code $exitCode');
      throw Exception('Upscayl failed with exit code $exitCode');
    }
  }

  void cancel() {
    if (_activeProcess != null) {
      _logger.w('Terminating rogue process PID: ${_activeProcess!.pid}');
      _activeProcess!.kill(ProcessSignal.sigterm);
      _activeProcess = null;
    }
  }
}
