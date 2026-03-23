import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/student_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final StudentModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dobController;
  String? _selectedGender;
  String? _selectedStream;

  String? _selectedClass;
  List<String> _selectedExams = [];

  List<String> _availableStreams = [];
  List<String> _availableExams = [];
  List<Map<String, dynamic>> _availableClasses = [];
  bool _loadingMetadata = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _dobController = TextEditingController(text: widget.user.dob);
    _selectedGender = widget.user.gender;
    _selectedStream = widget.user.stream;

    _selectedClass = widget.user.studentClass;
    _selectedExams = List.from(widget.user.competitiveExams);
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    try {
      final svc = ref.read(supabaseServiceProvider);
      final results = await Future.wait([
        svc.fetchStreams(),
        svc.fetchCompetitiveExams(),
        svc.fetchClasses(),
      ]);
      if (mounted) {
        setState(() {
          _availableStreams = List<String>.from(results[0]);
          _availableExams = List<String>.from(results[1]);
          _availableClasses = List<Map<String, dynamic>>.from(results[2]);
          _loadingMetadata = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMetadata = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      String? streamToSave;
      if (_selectedClass != null) {
        final selectedClassObj = _availableClasses.firstWhere(
          (e) => e['name'] == _selectedClass,
          orElse: () => {'class_type': 'JUNIOR'}, // Default if not found
        );
        final isSenior = selectedClassObj['class_type'] == 'SENIOR SECONDARY';

        if (isSenior) {
          streamToSave = _selectedStream;
        } else {
          streamToSave = 'Science'; // Default for junior classes
        }
      } else {
        streamToSave = 'Science'; // Default if no class is selected
      }

      // If XII+, must select at least one competitive exam
      if (_selectedClass == 'XII+' && (_selectedExams.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dropper (XII+) students must select at least one competitive exam',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      await ref
          .read(authProvider.notifier)
          .updateProfile(
            id: widget.user.id,
            name: _nameController.text,
            phone: _phoneController.text,
            gender: _selectedGender ?? '',
            stream: streamToSave,
            competitiveExams: _selectedExams,
            board: 'CBSE',
            dob: _dobController.text,
            studentClass: _selectedClass ?? '',
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMetadata) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'EDIT PROFILE',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'SAVE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildField('Full Name', _nameController),
            _buildField(
              'Phone Number',
              _phoneController,
              keyboardType: TextInputType.phone,
            ),
            _buildDatePicker('Date of Birth'),
            _buildDropdown(
              'Gender',
              ['MALE', 'FEMALE', 'OTHER'],
              _selectedGender,
              (v) => setState(() => _selectedGender = v),
            ),
            _buildDropdown('Class', _availableClasses.map((e) => e['name'].toString()).toList(), _selectedClass, (v) async {
              final selectedClassObj = _availableClasses.firstWhere((e) => e['name'] == v);
              final isSenior = selectedClassObj['class_type'] == 'SENIOR SECONDARY';
              
              setState(() {
                _selectedClass = v;
                _selectedStream = null;
                _availableStreams = [];
              });

              if (isSenior) {
                final svc = ref.read(supabaseServiceProvider);
                final linkedStreams = await svc.fetchStreams(classId: selectedClassObj['id']);
                if (mounted) setState(() => _availableStreams = linkedStreams);
              }
            }),
            if (_selectedClass != null && _availableStreams.isNotEmpty)
              _buildDropdown(
                'Stream',
                _availableStreams
                    .where((s) => s.toLowerCase() != 'science')
                    .toList(),
                _selectedStream,
                (v) => setState(() => _selectedStream = v),
              ),

            const SizedBox(height: 16),
            _buildExamsSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDatePicker(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: _dobController,
        readOnly: true,
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate:
                DateTime.tryParse(_dobController.text) ?? DateTime(2005),
            firstDate: DateTime(1990),
            lastDate: DateTime.now(),
          );
          if (date != null) {
            _dobController.text = DateFormat('yyyy-MM-dd').format(date);
          }
        },
        decoration: InputDecoration(
          labelText: label.toUpperCase(),
          labelStyle: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          suffixIcon: const Icon(Icons.calendar_today_rounded),
        ),
      ),
    );
  }

  Widget _buildExamsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPETITIVE EXAMS (MAX 3)',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _availableExams.map((exam) {
            final isSelected = _selectedExams.contains(exam);
            return FilterChip(
              label: Text(exam),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (_selectedExams.length < 3) _selectedExams.add(exam);
                  } else {
                    _selectedExams.remove(exam);
                  }
                });
              },
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
            );
          }).toList(),
        ),
      ],
    );
  }
}
