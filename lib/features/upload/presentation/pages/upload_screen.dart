import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/resource_model.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:project_v2/features/main_navigation/presentation/pages/main_navigation_bar.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _courseCodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _pdfUrlController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  
  String _selectedType = 'Notes'; // Default to Notes
  final List<String> _tags = [];
  PlatformFile? _pickedFile;
  bool _isLoading = false;
  bool _showPreview = false;
  final PdfViewerController _pdfPreviewController = PdfViewerController();



  static const List<String> _types = [
    'Notes',
    'Slides',
    'Question',
    'Book',
    'Assignments',
    'Other'
  ];

  static const List<String> _allowedExtensions = ['pdf', 'docx', 'pptx'];

  bool _isValidFile(String fileName) {
    final name = fileName.toLowerCase();
    return _allowedExtensions.any((ext) => name.endsWith('.$ext'));
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseCodeController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _pdfUrlController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: kIsWeb, // Mandatory for web
      );

      if (result != null) {
        final file = result.files.first;
        if (!_isValidFile(file.name)) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Unsupported file type! Only PDF, DOCx, and PPTx allowed.'), backgroundColor: Colors.red),
             );
           }
           return;
        }
        setState(() {
          _pickedFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _handleUpload() async {
    final String pdfUrl = _pdfUrlController.text.trim();
    
    if (_pickedFile == null && pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file or provide a PDF URL')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty || _subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and Subject are required')),
      );
      return;
    }

    // 0. Strict File Type Validation
    if (_pickedFile != null && !_isValidFile(_pickedFile!.name)) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Uploaded file type is invalid! Please pick a PDF, DOCx, or PPTx.'), backgroundColor: Colors.red),
       );
       return;
    }
    
    if (pdfUrl.isNotEmpty) {
       // Basic URL validation: ensure it has a scheme
       if (!pdfUrl.startsWith('http://') && !pdfUrl.startsWith('https://')) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please provide a valid URL (starting with http:// or https://)'), backgroundColor: Colors.red),
         );
         return;
       }
    }

    // 1. Mandatory Course Code for Questions
    final courseCode = _courseCodeController.text.trim();
    if (_selectedType == 'Question' && courseCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course Code is mandatory for Questions!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _firebaseService.currentUser;
      if (user == null) throw Exception('You must be logged in to upload resources');

      // 2. Duplicate Check for Questions
      if (_selectedType == 'Question') {
        final exists = await _firebaseService.checkQuestionExists(courseCode);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Question already exists for this Course Code!'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      String finalFileUrl = '';
      
      if (_pickedFile != null) {
        // Upload file to Firebase Storage
        if (kIsWeb) {
          if (_pickedFile!.bytes == null) throw Exception('File data is missing');
          finalFileUrl = await _firebaseService.uploadResourceFileWeb(_pickedFile!.bytes!, _pickedFile!.name);
        } else {
          if (_pickedFile!.path == null) throw Exception('File path is missing');
          final file = File(_pickedFile!.path!);
          finalFileUrl = await _firebaseService.uploadResourceFile(file, _pickedFile!.name);
        }
      } else {
        // Use provided URL
        finalFileUrl = pdfUrl;
      }

      final resource = ResourceModel(
        id: '', // Generated by Firebase
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        subject: _subjectController.text.trim(),
        courseCode: _courseCodeController.text.trim(),
        type: _selectedType,
        tags: _tags,
        fileurls: finalFileUrl,
        uploaderId: user.uid,
        createdAt: DateTime.now(),
      );

      final String newResourceId = await _firebaseService.createResource(resource);

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        bool wasUndone = false;

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Successfully published!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                wasUndone = true;
                scaffoldMessenger.removeCurrentSnackBar(); // Instant-hide the green bar to show the orange one next
                try {
                  await _firebaseService.deleteResource(newResourceId);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Upload completely erased.'), 
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } catch (undoError) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Failed to undo: $undoError'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
          ),
        );
        // Clear form
        setState(() {
          _pickedFile = null;
          _titleController.clear();
          _descriptionController.clear();
          _courseCodeController.clear();
          _pdfUrlController.clear();
          _subjectController.clear();
          _tags.clear();
          _selectedType = 'Notes';
        });

        // Redirect after precisely 3 seconds if not undone
        Future.delayed(const Duration(milliseconds: 3100), () {
          if (mounted && !wasUndone) {
            scaffoldMessenger.hideCurrentSnackBar(); // Smoothly hide it before pushing out
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainNavigationBar(initialIndex: 3)),
              (route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Upload Resource',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upload Area
            GestureDetector(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pickedFile != null ? Colors.green.withOpacity(0.3) : Theme.of(context).colorScheme.outlineVariant,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).brightness == Brightness.light 
                                ? Colors.black.withOpacity(0.05) 
                                : Colors.white.withOpacity(0.02),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _pickedFile != null ? Icons.description : Icons.cloud_upload_outlined, 
                        color: _pickedFile != null ? Colors.green : Colors.blue,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _pickedFile != null ? _pickedFile!.name : 'Select PDF or Document', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _pickedFile != null ? Colors.green : Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pickedFile != null 
                        ? '${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB'
                        : 'ONLY PDF, DOCx, PPTx allowed (Max 2MB)',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                    ),
                    if (_pickedFile != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => setState(() => _showPreview = !_showPreview),
                            icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility, size: 18),
                            label: Text(_showPreview ? 'Hide Preview' : 'Tap to Preview', style: const TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _pickedFile = null;
                              _showPreview = false;
                            }),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              backgroundColor: Colors.red.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_showPreview && _pickedFile != null && _pickedFile!.bytes != null) ...[
              const SizedBox(height: 16),
              Container(
                height: 350,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _pickedFile!.extension?.toLowerCase() == 'pdf'
                      ? SfPdfViewer.memory(
                          _pickedFile!.bytes!,
                          controller: _pdfPreviewController,
                        )
                      : InteractiveViewer(
                          child: Image.memory(_pickedFile!.bytes!),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            _label('Paste Resource / Web Link'),
            TextField(
              controller: _pdfUrlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/item/123',
                prefixIcon: Icon(Icons.link, size: 20),
              ),
              onChanged: (val) {
                if (val.isNotEmpty && _pickedFile != null) {
                  setState(() => _pickedFile = null);
                }
              },
            ),
            const SizedBox(height: 32),
            _label('Resource Title *'),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(hintText: 'e.g. Data Structures Notes'),
            ),
            const SizedBox(height: 20),
            _label('Subject *'),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(hintText: 'e.g. Computer Science'),
            ),
            const SizedBox(height: 20),
            _label('Upload Type *'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
                  onChanged: _isLoading ? null : (val) => setState(() => _selectedType = val!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _label('Course Code'),
            TextField(
              controller: _courseCodeController,
              decoration: const InputDecoration(hintText: 'e.g. CSE-201'),
            ),
            const SizedBox(height: 20),
            _label('Tags'),
            _tagsField(),
            const SizedBox(height: 20),
            _label('Description'),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What is this resource about?'),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _handleUpload,
                    child: const Text('Publish Resource'),
                  ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8)),
      ),
    );
  }

  Widget _tagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _tagController,
          decoration: InputDecoration(
            hintText: 'Press Enter to add tags',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _addTag,
            ),
          ),
          onSubmitted: (_) => _addTag(),
        ),
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tags.map((tag) => Chip(
                label: Text(tag, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onPrimary)),
                onDeleted: () => _removeTag(tag),
                backgroundColor: Theme.of(context).colorScheme.primary,
                deleteIconColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              )).toList(),
            ),
          ),
      ],
    );
  }
}
