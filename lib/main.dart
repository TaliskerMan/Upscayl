import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'services/upscayl_engine.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<UpscaylEngine>(create: (_) => UpscaylEngine()),
      ],
      child: const UpscaylApp(),
    ),
  );
}

class UpscaylApp extends StatelessWidget {
  const UpscaylApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscayl Native UI',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const UpscaylHome(),
    );
  }
}

class UpscaylHome extends StatefulWidget {
  const UpscaylHome({super.key});

  @override
  State<UpscaylHome> createState() => _UpscaylHomeState();
}

class _UpscaylHomeState extends State<UpscaylHome> {
  String? _inputPath;
  String? _outputDirPath;
  
  final List<String> _models = [
    'upscayl-standard-4x',
    'remacri-4x',
    'ultrasharp-4x',
    'ultramix-balanced-4x',
    'high-fidelity-4x',
    'digital-art-4x',
    'upscayl-lite-4x',
  ];
  String _selectedModel = 'upscayl-standard-4x';
  
  bool _useTTA = false;
  double _progress = 0;
  bool _isUpscaling = false;

  void _onUpscale() async {
    if (_inputPath == null) return;
    
    setState(() {
      _isUpscaling = true;
      _progress = 0;
    });

    final defaultOutputDir = p.dirname(_inputPath!);
    final outputDir = _outputDirPath ?? defaultOutputDir;
    final extension = p.extension(_inputPath!);
    final nameWithoutExt = p.basenameWithoutExtension(_inputPath!);
    // e.g. /home/user/Pictures/image_upscayled.png
    final finalOutputPath = p.join(outputDir, '${nameWithoutExt}_upscayled$extension');

    final engine = context.read<UpscaylEngine>();
    
    try {
      await for (final progress in engine.runUpscayl(
        inputPath: _inputPath!,
        outputPath: finalOutputPath,
        modelName: _selectedModel,
        useTTA: _useTTA,
      )) {
        setState(() => _progress = progress);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully saved to $finalOutputPath!', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        )
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Execution Error: $e'),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 10),
        )
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpscaling = false;
          _progress = 1.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upscayl Native Engine \u{1F680}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STEP 1: Input Image
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(24),
                leading: const Icon(Icons.add_photo_alternate_rounded, size: 48, color: Colors.deepPurpleAccent),
                title: const Text('1. Select Image', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: Text(_inputPath ?? 'No file selected yet.\nClick here to browse...', style: const TextStyle(fontSize: 16, height: 1.5)),
                onTap: _isUpscaling ? null : () async {
                  final result = await FilePicker.platform.pickFiles(type: FileType.image);
                  if (result != null) {
                    setState(() => _inputPath = result.files.single.path);
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // STEP 2: Upscayl Type
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 48, color: Colors.deepPurpleAccent),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2. Select Upscaling Model', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedModel,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: _models.map((model) {
                              return DropdownMenuItem(
                                value: model,
                                child: Text(model, style: const TextStyle(fontSize: 16)),
                              );
                            }).toList(),
                            onChanged: _isUpscaling ? null : (val) {
                              if (val != null) setState(() => _selectedModel = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Max Quality (TTA Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: const Text('Drastically reduces noise and AI artifacts via 8x passes, but is much slower.'),
                            value: _useTTA,
                            activeColor: Colors.deepPurpleAccent,
                            contentPadding: EdgeInsets.zero,
                            onChanged: _isUpscaling ? null : (bool val) {
                              setState(() {
                                _useTTA = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // STEP 3: Output Folder
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(24),
                leading: const Icon(Icons.create_new_folder_rounded, size: 48, color: Colors.deepPurpleAccent),
                title: const Text('3. Set Output Folder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                subtitle: Text(_outputDirPath ?? 'Leave empty to save alongside the original file.\nClick to change...', style: const TextStyle(fontSize: 16, height: 1.5)),
                onTap: _isUpscaling ? null : () async {
                  final result = await FilePicker.platform.getDirectoryPath();
                  if (result != null) {
                    setState(() => _outputDirPath = result);
                  }
                },
              ),
            ),
            
            const SizedBox(height: 48),

            // Progress Header
            if (_isUpscaling || _progress == 1.0)
              Column(
                children: [
                  Text(
                    _progress == 1.0 && !_isUpscaling ? 'Complete!' : 'Upscaling: ${(_progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progress, 
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                ]
              ),

            // STEP 4: Submit Core
            ElevatedButton.icon(
              onPressed: _isUpscaling || _inputPath == null ? null : _onUpscale,
              icon: _isUpscaling ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.bolt, size: 32),
              label: Text(
                _isUpscaling ? 'PROCESSING...' : 'UPSCAYL', 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
