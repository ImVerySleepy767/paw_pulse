import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/utils/error_formatter.dart';
import 'package:pawpulse/utils/date_formatter.dart';

enum _FilterMode { pet, weightRange, petAndCalories, timeOfDay }

class InsightsScreen extends ConsumerStatefulWidget {
  static const String routeName = '/insights';
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  _FilterMode _mode = _FilterMode.pet;
  String? _selectedPet;
  bool _sortDescending = true;

  final _minWeightController = TextEditingController();
  final _maxWeightController = TextEditingController();
  double? _appliedMinWeight;
  double? _appliedMaxWeight;

  final _minCaloriesController = TextEditingController();
  int? _appliedMinCalories;

  String _selectedTimePeriod = 'Morning';

  Map<String, double>? _aggregates;
  bool _loadingAggregates = true;
  String? _aggregatesError;

  List<String> _petNames = [];
  bool _loadingPetNames = true;

  @override
  void initState() {
    super.initState();
    _loadAggregates();
    _loadPetNames();
  }

  @override
  void dispose() {
    _minWeightController.dispose();
    _maxWeightController.dispose();
    _minCaloriesController.dispose();
    super.dispose();
  }

  Future<void> _loadAggregates() async {
    setState(() {
      _loadingAggregates = true;
      _aggregatesError = null;
    });
    try {
      final result = await ref.read(firebaseServiceProvider).getHealthLogAggregates();
      if (mounted) {
        setState(() {
          _aggregates = result;
          _loadingAggregates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aggregatesError = friendlyFirebaseError(e);
          _loadingAggregates = false;
        });
      }
    }
  }

  Future<void> _loadPetNames() async {
    setState(() => _loadingPetNames = true);
    try {
      final names = await ref.read(firebaseServiceProvider).getDistinctPetNames();
      if (mounted) {
        setState(() {
          _petNames = names;
          _loadingPetNames = false;
          if (_selectedPet != null && !_petNames.contains(_selectedPet)) {
            _selectedPet = null;
          }
          if (_selectedPet == null && _petNames.isNotEmpty) {
            _selectedPet = _petNames.first;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPetNames = false);
    }
  }

  Stream<QuerySnapshot>? _buildStream() {
    final service = ref.read(firebaseServiceProvider);
    switch (_mode) {
      case _FilterMode.pet:
        if (_selectedPet == null) return null;
        return service.getLogsByPetName(_selectedPet!, descending: _sortDescending);
      case _FilterMode.weightRange:
        if (_appliedMinWeight == null || _appliedMaxWeight == null) return null;
        return service.getLogsByWeightRange(_appliedMinWeight!, _appliedMaxWeight!);
      case _FilterMode.petAndCalories:
        if (_selectedPet == null || _appliedMinCalories == null) return null;
        return service.getLogsByPetAndMinCalories(_selectedPet!, _appliedMinCalories!);
      case _FilterMode.timeOfDay:
        return service.getLogsByTimePeriod(_selectedTimePeriod, descending: _sortDescending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsStream = _buildStream();

    return Scaffold(
      appBar: AppBar(title: const Text('Pet Insights')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAggregates();
          await _loadPetNames();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loadingAggregates
                    ? const Center(child: CircularProgressIndicator())
                    : _aggregatesError != null
                        ? Text(_aggregatesError!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatTile(label: 'Total Logs', value: '${_aggregates?['count']?.toInt() ?? 0}'),
                              _StatTile(label: 'Avg Calories', value: '${_aggregates?['avgCalories']?.toStringAsFixed(0) ?? 0} kcal'),
                              _StatTile(label: 'Avg Weight', value: '${_aggregates?['avgWeight']?.toStringAsFixed(1) ?? 0} kg'),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Filter by', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(label: const Text('Pet'), selected: _mode == _FilterMode.pet, onSelected: (_) => setState(() => _mode = _FilterMode.pet)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Weight Range'), selected: _mode == _FilterMode.weightRange, onSelected: (_) => setState(() => _mode = _FilterMode.weightRange)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Pet + Min Calories'), selected: _mode == _FilterMode.petAndCalories, onSelected: (_) => setState(() => _mode = _FilterMode.petAndCalories)),
                  const SizedBox(width: 8),
                  ChoiceChip(label: const Text('Time of Day'), selected: _mode == _FilterMode.timeOfDay, onSelected: (_) => setState(() => _mode = _FilterMode.timeOfDay)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildModeControls(),
            const SizedBox(height: 12),
            if (logsStream == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Choose filter values above to see results.')),
              )
            else
              StreamBuilder<QuerySnapshot>(
                stream: logsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Error loading logs:\n${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No matching logs found.')));
                  }
                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          title: Text('${data['pet_name']} — ${formatLogDate(data['log_date'])}'),
                          subtitle: Text(
                            'Weight: ${data['weight']}kg | Calories: ${data['calorie_intake']} kcal'
                            '${data['time_period'] != null ? ' | ${data['time_period']}' : ''}',
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeControls() {
    switch (_mode) {
      case _FilterMode.pet:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedPet,
                decoration: InputDecoration(
                  labelText: 'Pet',
                  border: const OutlineInputBorder(),
                  suffixIcon: _loadingPetNames
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                ),
                items: _petNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: (val) => setState(() => _selectedPet = val),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: _sortDescending ? 'Newest first' : 'Oldest first',
              onPressed: () => setState(() => _sortDescending = !_sortDescending),
              icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
            ),
          ],
        );
      case _FilterMode.weightRange:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Min weight (kg)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxWeightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Max weight (kg)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final min = double.tryParse(_minWeightController.text);
                  final max = double.tryParse(_maxWeightController.text);
                  if (min == null || max == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid numbers for both min and max weight.')));
                    return;
                  }
                  setState(() {
                    _appliedMinWeight = min;
                    _appliedMaxWeight = max;
                  });
                },
                child: const Text('Apply Weight Filter'),
              ),
            ),
          ],
        );
      case _FilterMode.petAndCalories:
        return Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedPet,
              decoration: const InputDecoration(labelText: 'Pet', border: OutlineInputBorder()),
              items: _petNames.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
              onChanged: (val) => setState(() => _selectedPet = val),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _minCaloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum calories (kcal)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final minCal = int.tryParse(_minCaloriesController.text);
                  if (_selectedPet == null || minCal == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick a pet and enter a valid minimum calorie value.')));
                    return;
                  }
                  setState(() => _appliedMinCalories = minCal);
                },
                child: const Text('Apply Filter'),
              ),
            ),
          ],
        );
      case _FilterMode.timeOfDay:
        return Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Morning', 'Afternoon', 'Night'].map((period) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(period),
                        selected: _selectedTimePeriod == period,
                        onSelected: (_) => setState(() => _selectedTimePeriod = period),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            IconButton(
              tooltip: _sortDescending ? 'Newest first' : 'Oldest first',
              onPressed: () => setState(() => _sortDescending = !_sortDescending),
              icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward),
            ),
          ],
        );
    }
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}