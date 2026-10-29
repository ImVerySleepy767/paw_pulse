import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/utils/error_formatter.dart';

class EditLogScreen extends ConsumerStatefulWidget {
  static const String routeName = '/edit-log';
  final String docId;
  final Map<String, dynamic> initialData;

  const EditLogScreen({super.key, required this.docId, required this.initialData});

  @override
  ConsumerState<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends ConsumerState<EditLogScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _petName;
  late int _calories;
  late int _restTime;
  late double _weight;

  @override
  void initState() {
    super.initState();
    _petName = widget.initialData['pet_name'] ?? '';
    _calories = widget.initialData['calorie_intake'] ?? 0;
    _restTime = widget.initialData['pet_resttime'] ?? 0;
    _weight = (widget.initialData['weight'] as num?)?.toDouble() ?? 0.0;
  }

  void _updateForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      await ref.read(firebaseServiceProvider).updateHealthLog(
        docId: widget.docId,
        petName: _petName,
        calorieIntake: _calories,
        weight: _weight,
        petRestTime: _restTime,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet metric updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyFirebaseError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Daily Pet Log')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              initialValue: _petName,
              decoration: const InputDecoration(labelText: 'Pet Name'),
              validator: (val) => val == null || val.isEmpty ? 'Enter pet name' : null,
              onSaved: (val) => _petName = val!,
            ),
            TextFormField(
              initialValue: _calories.toString(),
              decoration: const InputDecoration(labelText: 'Calorie Intake (kcal)'),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter calories';
                if (int.tryParse(val) == null) return 'Please enter a valid number';
                return null;
              },
              onSaved: (val) => _calories = int.parse(val!),
            ),
            TextFormField(
              initialValue: _restTime.toString(),
              decoration: const InputDecoration(labelText: 'Rest Duration (Minutes)'),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter rest time';
                if (int.tryParse(val) == null) return 'Please enter a valid number';
                return null;
              },
              onSaved: (val) => _restTime = int.parse(val!),
            ),
            TextFormField(
              initialValue: _weight.toString(),
              decoration: const InputDecoration(labelText: 'Current Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter weight';
                if (double.tryParse(val) == null) return 'Please enter a valid decimal number';
                return null;
              },
              onSaved: (val) => _weight = double.parse(val!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateForm,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Update Metric'),
            )
          ],
        ),
      ),
    );
  }
}