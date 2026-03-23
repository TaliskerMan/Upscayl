import 'dart:io';
import 'dart:convert';

class UpscaylEngine {
  Process? _activeProcess;

  /// Executes Upscayl binary cleanly via native processes
  Stream<double> runUpscayl({
    required String inputPath,
    required String outputPath,
    required String modelName,
    bool useTTA = false,
  }) async* {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final flutterAssetsDir = '$exeDir/data/flutter_assets/assets';
    final upscaylBinPath = '$flutterAssetsDir/linux/bin/upscayl-bin';
    final modelsPath = '$flutterAssetsDir/models';

    print('==== UPSCAYL NATIVE EXECUTION ====');
    print('Executable Dir: $exeDir');
    print('Binary Path: $upscaylBinPath');
    print('Models Path: $modelsPath');
    print('Input: $inputPath');
    print('Output: $outputPath');
    print('Model Type: $modelName');
    print('TTA Enabled: $useTTA');

    // Ensure it's executable
    if (Platform.isLinux || Platform.isMacOS) {
      print('Making binary executable...');
      await Process.run('chmod', ['+x', upscaylBinPath]);
    }

    print('Spawning Subprocess...');
    
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

    // Realesrgan-ncnn-vulkan usually outputs progress to stderr, e.g., "12.34%"
    await for (final bytes in _activeProcess!.stderr) {
      final text = utf8.decode(bytes, allowMalformed: true);
      // print('STDERR: $text'); // Uncomment if we need extreme verbosity
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
    print('Process Exited with Code: $exitCode');
    
    if (exitCode != 0) {
      throw Exception('Upscayl failed with exit code $exitCode');
    }
  }

  void cancel() {
    _activeProcess?.kill();
    _activeProcess = null;
  }
}
