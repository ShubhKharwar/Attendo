import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart'; // Add this import

class TeacherUploadPage extends StatefulWidget {
  const TeacherUploadPage({super.key});

  @override
  State<TeacherUploadPage> createState() => _TeacherUploadPageState();
}

class _TeacherUploadPageState extends State<TeacherUploadPage> {
  final _storage = const FlutterSecureStorage();

  // Upload states
  bool _isUploadingStudents = false;
  bool _isUploadingTimetable = false;

  // Selected files - now just file paths
  String? _selectedStudentFilePath;
  String? _selectedTimetableFilePath;

  // Upload results
  String? _studentUploadResult;
  String? _timetableUploadResult;
  bool _studentUploadSuccess = false;
  bool _timetableUploadSuccess = false;

  Future<void> _pickStudentFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        final platformFile = result.files.single;

        // Use the mime type provided by the file picker
        if (platformFile.path != null && platformFile.extension?.toLowerCase() == 'pdf') {
          setState(() {
            _selectedStudentFilePath = platformFile.path;
            _studentUploadResult = null;
          });
        } else {
          _showErrorSnackBar('Please select a valid PDF file.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking student file: $e');
    }
  }

  Future<void> _pickTimetableFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null) {
        final platformFile = result.files.single;

        // Use the mime type provided by the file picker
        if (platformFile.path != null && platformFile.extension?.toLowerCase() == 'pdf') {
          setState(() {
            _selectedTimetableFilePath = platformFile.path;
            _timetableUploadResult = null;
          });
        } else {
          _showErrorSnackBar('Please select a valid PDF file.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error picking timetable file: $e');
    }
  }

  Future<void> _uploadStudentList() async {
    if (_selectedStudentFilePath == null) {
      _showErrorSnackBar('Please select a student list PDF first');
      return;
    }

    setState(() {
      _isUploadingStudents = true;
      _studentUploadResult = null;
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _showErrorSnackBar('Authentication token not found');
        return;
      }

      final uri = Uri.parse('http://192.168.0.105:3000/api/v1/admin/upload');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      final file = File(_selectedStudentFilePath!);
      if (await file.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'studentListPdf',
          _selectedStudentFilePath!,
          contentType: MediaType('application', 'pdf'), // Explicitly set content type
        ));
      } else {
        _showErrorSnackBar('File not found');
        return;
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 201 || response.statusCode == 207) {
        setState(() {
          _studentUploadSuccess = true;
          _studentUploadResult = responseData['message'] ?? 'Upload successful';
        });
        _showSuccessSnackBar('Student list uploaded successfully!');
      } else {
        setState(() {
          _studentUploadSuccess = false;
          _studentUploadResult = responseData['message'] ?? 'Upload failed';
        });
        _showErrorSnackBar(_studentUploadResult!);
      }
    } catch (e) {
      setState(() {
        _studentUploadSuccess = false;
        _studentUploadResult = 'Error: $e';
      });
      _showErrorSnackBar('Upload failed: $e');
    } finally {
      setState(() {
        _isUploadingStudents = false;
      });
    }
  }

  Future<void> _uploadTimetable() async {
    if (_selectedTimetableFilePath == null) {
      _showErrorSnackBar('Please select a timetable PDF first');
      return;
    }

    setState(() {
      _isUploadingTimetable = true;
      _timetableUploadResult = null;
    });

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        _showErrorSnackBar('Authentication token not found');
        return;
      }

      final uri = Uri.parse('http://192.168.0.105:3000/api/v1/admin/upload-timetable');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      final file = File(_selectedTimetableFilePath!);
      if (await file.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'timetablePdf',
          _selectedTimetableFilePath!,
          contentType: MediaType('application', 'pdf'), // Explicitly set content type
        ));
      } else {
        _showErrorSnackBar('File not found');
        return;
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200) {
        setState(() {
          _timetableUploadSuccess = true;
          _timetableUploadResult = responseData['message'] ?? 'Upload successful';
        });
        _showSuccessSnackBar('Timetable uploaded successfully!');
      } else {
        setState(() {
          _timetableUploadSuccess = false;
          _timetableUploadResult = responseData['message'] ?? 'Upload failed';
        });
        _showErrorSnackBar(_timetableUploadResult!);
      }
    } catch (e) {
      setState(() {
        _timetableUploadSuccess = false;
        _timetableUploadResult = 'Error: $e';
      });
      _showErrorSnackBar('Upload failed: $e');
    } finally {
      setState(() {
        _isUploadingTimetable = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getFileName(String? filePath) {
    if (filePath == null) return 'No file selected';
    return filePath.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Upload Data',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Student Lists & Timetables',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload PDF files to automatically process student data and timetables',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // Student List Upload Section
                _buildUploadSection(
                  title: 'Student List',
                  description: 'Upload PDF containing student information',
                  selectedFilePath: _selectedStudentFilePath,
                  isUploading: _isUploadingStudents,
                  uploadResult: _studentUploadResult,
                  uploadSuccess: _studentUploadSuccess,
                  onPickFile: _pickStudentFile,
                  onUpload: _uploadStudentList,
                  icon: Icons.people,
                ),

                const SizedBox(height: 32),

                // Timetable Upload Section
                _buildUploadSection(
                  title: 'Timetable',
                  description: 'Upload PDF containing class timetables',
                  selectedFilePath: _selectedTimetableFilePath,
                  isUploading: _isUploadingTimetable,
                  uploadResult: _timetableUploadResult,
                  uploadSuccess: _timetableUploadSuccess,
                  onPickFile: _pickTimetableFile,
                  onUpload: _uploadTimetable,
                  icon: Icons.schedule,
                ),

                const SizedBox(height: 32), // Reduced space to make it fit better

                // Info section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Only PDF files are supported\n'
                            '• Student lists will create user accounts automatically\n'
                            '• Timetables will be assigned to students and teachers\n'
                            '• Processing may take a few moments',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
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
    );
  }

  Widget _buildUploadSection({
    required String title,
    required String description,
    required String? selectedFilePath,
    required bool isUploading,
    required String? uploadResult,
    required bool uploadSuccess,
    required VoidCallback onPickFile,
    required VoidCallback onUpload,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          // File selection
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getFileName(selectedFilePath),
                    style: TextStyle(
                      color: selectedFilePath != null ? Colors.white : Colors.grey[500],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isUploading ? null : onPickFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text(
                  'Choose File',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Upload button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (selectedFilePath != null && !isUploading) ? onUpload : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isUploading
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : Text(
                'Upload $title',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Upload result
          if (uploadResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: uploadSuccess ? Colors.green[900] : Colors.red[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    uploadSuccess ? Icons.check_circle : Icons.error,
                    color: uploadSuccess ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uploadResult!,
                      style: TextStyle(
                        color: uploadSuccess ? Colors.green[100] : Colors.red[100],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}