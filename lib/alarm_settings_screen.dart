import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:async';

class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  AlarmSettingsScreenState createState() => AlarmSettingsScreenState();
}

class AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  String? _selectedFileName;
  String? _selectedFilePath;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Timer? _testAlarmTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedAlarmFile();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _testAlarmTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedAlarmFile() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('alarm_file_path');
    final name = prefs.getString('alarm_file_name');
    setState(() {
      _selectedFilePath = path;
      _selectedFileName = name;
    });
  }

  Future<void> _pickAlarmFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('alarm_file_path', _selectedFilePath!);
        await prefs.setString('alarm_file_name', _selectedFileName!);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom alarm sound saved: $_selectedFileName'),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting alarm sound'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _removeCustomAlarm() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_file_path');
      await prefs.remove('alarm_file_name');

      setState(() {
        _selectedFileName = null;
        _selectedFilePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom alarm removed. Using default alarm.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error removing custom alarm'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testAlarmSound() async {
    if (_isPlaying) {
      _stopTestAlarm();
      return;
    }

    setState(() {
      _isPlaying = true;
    });

    // Cancel any existing timer
    _testAlarmTimer?.cancel();

    try {
      // Set up alarm completion listener for looping
      _audioPlayer.onPlayerComplete.listen((_) {
        if (_isPlaying && mounted) {
          // Loop the alarm if still playing
          _playTestAlarmSound();
        }
      });

      // Start playing the alarm
      await _playTestAlarmSound();

      // Set timer to stop after 1 minute
      _testAlarmTimer = Timer(const Duration(minutes: 1), () {
        if (_isPlaying && mounted) {
          _stopTestAlarm();
        }
      });
    } catch (e) {
      setState(() {
        _isPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error playing alarm sound'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _playTestAlarmSound() async {
    try {
      if (_selectedFilePath != null) {
        // Play custom alarm sound
        await _audioPlayer.play(DeviceFileSource(_selectedFilePath!));
      } else {
        // Play default alarm sound
        await _audioPlayer.play(AssetSource('alarm.mp3'));
      }
    } catch (e) {
      _stopTestAlarm();
    }
  }

  void _stopTestAlarm() {
    _audioPlayer.stop();
    _testAlarmTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.music_note,
                color: Colors.green.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Alarm Customization'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Alarm Status Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _selectedFileName != null
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                      _selectedFileName != null
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _selectedFileName != null
                                  ? Colors.green.shade600
                                  : Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _selectedFileName != null
                                  ? FontAwesomeIcons.music
                                  : FontAwesomeIcons.bell,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName != null
                                      ? 'Custom Alarm Active'
                                      : 'Default Alarm Active',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedFileName != null
                                        ? Colors.green.shade900
                                        : Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedFileName != null
                                      ? 'Using your custom sound'
                                      : 'Using built-in alarm sound',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedFileName != null
                                        ? Colors.green.shade700
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_selectedFileName != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.fileAudio,
                                color: Colors.green.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedFileName!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Alarm Sound Options',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Test Alarm Button
                    ElevatedButton.icon(
                      icon: Icon(
                        _isPlaying ? Icons.stop : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isPlaying ? 'Stop Test' : 'Test Alarm Sound',
                      ),
                      onPressed: _isLoading ? null : _testAlarmSound,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Pick Custom Alarm Button
                    OutlinedButton.icon(
                      icon: Icon(
                        Icons.music_note,
                        color: Colors.green.shade600,
                      ),
                      label: const Text('Choose Custom Alarm'),
                      onPressed: _isLoading ? null : _pickAlarmFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade600,
                        side: BorderSide(
                          color: Colors.green.shade600,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 16),

                      // Remove Custom Alarm Button
                      OutlinedButton.icon(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade600,
                        ),
                        label: const Text('Remove Custom Alarm'),
                        onPressed: _isLoading ? null : _removeCustomAlarm,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(
                            color: Colors.red.shade600,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    if (_isLoading) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Info Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.circleInfo,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Supported Formats',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• MP3, WAV, OGG, M4A files\n• Maximum file size: 10MB\n• Your custom alarm will play at 5km, 2km, and 1km from destination',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
