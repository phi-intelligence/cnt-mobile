import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Stream Creation Screen - Create new live stream
class StreamCreationScreen extends StatefulWidget {
  const StreamCreationScreen({super.key});

  @override
  State<StreamCreationScreen> createState() => _StreamCreationScreenState();
}

class _StreamCreationScreenState extends State<StreamCreationScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isScheduled = false;
  DateTime? _scheduledDate;

  final List<String> _categories = [
    'General',
    'Sermon',
    'Prayer',
    'Bible Study',
    'Testimony',
    'Music',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: const Text('Create Stream'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _createStream,
            child: const Text(
              'Create',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.large),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Stream Title',
              hintText: 'Enter stream title',
            ),
            maxLength: 100,
          ),
          const SizedBox(height: AppSpacing.large),

          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Describe your stream',
            ),
            maxLines: 3,
            maxLength: 500,
          ),
          const SizedBox(height: AppSpacing.large),

          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Category',
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          const SizedBox(height: AppSpacing.large),

          SwitchListTile(
            title: const Text('Schedule Stream'),
            subtitle: const Text('Choose when to start the stream'),
            value: _isScheduled,
            onChanged: (value) {
              setState(() {
                _isScheduled = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.large),

          if (_isScheduled)
            ElevatedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(_scheduledDate == null
                  ? 'Select Date & Time'
                  : '${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}'),
            ),
        ],
      ),
    );
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _scheduledDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _createStream() {
    // TODO: Create stream and navigate to broadcaster
    Navigator.pop(context);
  }
}

