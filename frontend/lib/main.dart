import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/api_service.dart';

void main() => runApp(const DocuLensApp());

class DocuLensApp extends StatelessWidget {
  const DocuLensApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DocuLens',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D776A)),
      scaffoldBackgroundColor: const Color(0xFFF5F8F7),
    ),
    home: const DocuLensHome(),
  );
}

enum _Page { home, input, analyzing, result, task, history }

class DocuLensHome extends StatefulWidget {
  const DocuLensHome({super.key});
  @override
  State<DocuLensHome> createState() => _DocuLensHomeState();
}

class _DocuLensHomeState extends State<DocuLensHome> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final _text = TextEditingController(
    text: '''Machine: M104

Checked today

Temp: 82 C
Vib: HIGH
Oil: OK

Filter needs changing

Check again next week

Worker: Amit''',
  );
  _Page _page = _Page.home;
  XFile? _image;
  bool _imageLoading = false;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _inspection;
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _inspections = [], _tasks = [];
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _input() => setState(() {
    _page = _Page.input;
    _error = null;
    _image = null;
    _text.clear();
  });

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _imageLoading = true;
      _error = null;
    });
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null && mounted) {
        setState(() => _image = image);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to pick image: $e');
    } finally {
      if (mounted) setState(() => _imageLoading = false);
    }
  }

  Future<void> _analyze() async {
    if (_text.text.trim().isEmpty && _image == null) {
      setState(() => _error = 'Enter an observation or choose an image first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _page = _Page.analyzing;
    });
    try {
      final result = await _api.analyze(text: _text.text, image: _image);
      if (mounted)
        setState(() {
          _inspection = result;
          _page = _Page.result;
        });
    } on ApiException catch (error) {
      if (mounted)
        setState(() {
          _error = error.message;
          _page = _Page.input;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error =
              'Could not reach DocuLens. Check the backend URL and connection.';
          _page = _Page.input;
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTask() async {
    if (_inspection == null) return;
    setState(() => _loading = true);
    try {
      final result = await _api.createTask(inspection: _inspection!);
      if (mounted)
        setState(() {
          _task = result;
          _page = _Page.task;
        });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _history() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = _Page.history;
    });
    try {
      final results = await Future.wait([
        _api.history('/inspections', 'inspections'),
        _api.history('/tasks', 'tasks'),
      ]);
      if (mounted)
        setState(() {
          _inspections = results[0];
          _tasks = results[1];
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_page) {
      _Page.home => _Home(onInput: _input, onHistory: _history),
      _Page.input => _Input(
        text: _text,
        image: _image,
        imageLoading: _imageLoading,
        error: _error,
        onCamera: () => _pick(ImageSource.camera),
        onGallery: () => _pick(ImageSource.gallery),
        onRemoveImage: () => setState(() => _image = null),
        onAnalyze: _analyze,
      ),
      _Page.analyzing => const _Analyzing(),
      _Page.result => _Result(
        inspection: _inspection!,
        onCreateTask: _createTask,
      ),
      _Page.task => _Task(task: _task!, onHistory: _history),
      _Page.history => _History(
        inspections: _inspections,
        tasks: _tasks,
        error: _error,
        loading: _loading,
      ),
    };
    return Scaffold(
      appBar: _page == _Page.home
          ? null
          : AppBar(
              title: const Text('DocuLens'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _page = _Page.home),
              ),
            ),
      body: SafeArea(child: body),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.onInput, required this.onHistory});
  final VoidCallback onInput, onHistory;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 28),
      const Icon(
        Icons.document_scanner_outlined,
        size: 58,
        color: Color(0xFF0D776A),
      ),
      const SizedBox(height: 20),
      Text(
        'DocuLens',
        style: Theme.of(context).textTheme.displaySmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      const Text(
        'Turn messy field observations into clear maintenance actions.',
        style: TextStyle(fontSize: 18, height: 1.4),
      ),
      const SizedBox(height: 32),
      const _Feature(
        icon: Icons.auto_awesome,
        title: 'Understand observations',
        subtitle: 'Images or notes become structured operational data.',
      ),
      const SizedBox(height: 12),
      const _Feature(
        icon: Icons.warning_amber_rounded,
        title: 'Spot maintenance risk',
        subtitle: 'Validation and risk rules highlight what needs attention.',
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: onInput,
        icon: const Icon(Icons.document_scanner),
        label: const Text('Scan Observation'),
        style: _button,
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: onInput,
        icon: const Icon(Icons.edit_note),
        label: const Text('Enter Manually'),
        style: _button,
      ),
      const SizedBox(height: 10),
      TextButton.icon(
        onPressed: onHistory,
        icon: const Icon(Icons.history),
        label: const Text('Inspection History'),
      ),
    ],
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.text,
    required this.image,
    required this.imageLoading,
    required this.error,
    required this.onCamera,
    required this.onGallery,
    required this.onRemoveImage,
    required this.onAnalyze,
  });
  final TextEditingController text;
  final XFile? image;
  final bool imageLoading;
  final String? error;
  final VoidCallback onCamera, onGallery, onRemoveImage, onAnalyze;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Capture field observation',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Upload a handwritten note or enter its contents. DocuLens analyzes the original input.',
      ),
      const SizedBox(height: 20),
      if (imageLoading)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Attaching image...',
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        )
      else if (image != null)
        Card(
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 180,
                    child: kIsWeb
                        ? Image.network(
                            image!.path,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(image!.path),
                            fit: BoxFit.cover,
                          ),
                  ),
                  Container(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Image attached: ${image!.name}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onRemoveImage,
                    tooltip: 'Remove image',
                  ),
                ),
              ),
            ],
          ),
        ),
      if (!imageLoading && image == null)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Choose image'),
              ),
            ),
          ],
        )
      else if (!imageLoading && image != null)
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Change (Camera)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Change (Gallery)'),
              ),
            ),
          ],
        ),
      const SizedBox(height: 20),
      TextField(
        controller: text,
        minLines: 9,
        maxLines: 14,
        decoration: const InputDecoration(
          labelText: 'Observation text',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
          hintText: 'e.g. M104 checked. vibration high...',
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: onAnalyze,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Analyze Observation'),
        style: _button,
      ),
    ],
  );
}

class _Analyzing extends StatelessWidget {
  const _Analyzing();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(
          'Analyzing field observation...',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        Text('Extracting and validating maintenance data.'),
      ],
    ),
  );
}

class _Result extends StatelessWidget {
  const _Result({required this.inspection, required this.onCreateTask});
  final Map<String, dynamic> inspection;
  final VoidCallback onCreateTask;
  @override
  Widget build(BuildContext context) {
    final readings = (inspection['readings'] as List? ?? []).cast<Map>();
    final issues = (inspection['detected_issues'] as List? ?? []).cast<Map>();
    final actions = (inspection['recommended_actions'] as List? ?? [])
        .cast<Map>();
    final priority = '${inspection['risk_priority'] ?? 'LOW'}';
    String value(String parameter) {
      final r = readings
          .where((item) => item['parameter'] == parameter)
          .firstOrNull;
      if (r == null) return 'Not recorded';
      return r['value'] == null
          ? '${r['status']}'
          : '${r['value']} ${r['unit'] ?? ''} · ${r['status']}';
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Inspection result',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text('AI understanding → structured operational data'),
        const SizedBox(height: 20),
        _Section(
          'Structured inspection',
          Column(
            children: [
              _Row(
                'Machine',
                '${inspection['machine_id'] ?? 'Not identified'}',
              ),
              _Row('Temperature', value('temperature')),
              _Row('Vibration', value('vibration')),
              _Row('Oil', value('oil_level')),
              _Row('Filter', value('filter')),
              _Row(
                'Next inspection',
                '${inspection['next_inspection'] ?? 'Not scheduled'}',
              ),
              _Row(
                'Worker',
                '${inspection['worker_name'] ?? 'Not identified'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          'Risk & recommendation',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Priority(priority),
              const SizedBox(height: 14),
              const Text(
                'Detected issues',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (issues.isEmpty)
                const Text('No operational issues detected.')
              else
                ...issues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${issue['description']}'),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Recommended action',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                actions.isEmpty
                    ? 'Review the inspection readings.'
                    : '${actions.first['action']}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onCreateTask,
          icon: const Icon(Icons.build_circle_outlined),
          label: const Text('Create Maintenance Task'),
          style: _button,
        ),
      ],
    );
  }
}

class _Task extends StatelessWidget {
  const _Task({required this.task, required this.onHistory});
  final Map<String, dynamic> task;
  final VoidCallback onHistory;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Maintenance task created',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        _Section(
          'Task #${task['task_number'] ?? task['id']}',
          Column(
            children: [
              _Row('Machine', '${task['machine_id'] ?? 'Not assigned'}'),
              _Row('Priority', '${task['priority'] ?? 'MEDIUM'}'),
              _Row('Status', '${task['status'] ?? 'OPEN'}'),
              _Row('Action', '${task['title'] ?? 'Inspect equipment'}'),
              _Row('Created', _date(task['created_at'])),
            ],
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onHistory,
          icon: const Icon(Icons.history),
          label: const Text('View History'),
          style: _button,
        ),
      ],
    ),
  );
}

class _History extends StatelessWidget {
  const _History({
    required this.inspections,
    required this.tasks,
    required this.error,
    required this.loading,
  });
  final List<Map<String, dynamic>> inspections, tasks;
  final String? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              'History',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          TabBar(
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                icon: const Icon(Icons.assignment_outlined),
                text: 'Inspections (${inspections.length})',
              ),
              Tab(
                icon: const Icon(Icons.build_circle_outlined),
                text: 'Tasks (${tasks.length})',
              ),
            ],
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      )
                    : TabBarView(
                        children: [
                          _buildInspectionsList(context),
                          _buildTasksList(context),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionsList(BuildContext context) {
    if (inspections.isEmpty) {
      return const Center(child: Text('No inspections yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: inspections.length,
      itemBuilder: (context, index) {
        final i = inspections[index];
        return _HistoryCard(
          '${i['machine_id'] ?? 'Unidentified machine'} · ${i['risk_priority'] ?? 'LOW'}',
          _date(i['created_at']),
          icon: Icons.assignment_outlined,
        );
      },
    );
  }

  Widget _buildTasksList(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('No tasks yet.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final t = tasks[index];
        return _HistoryCard(
          'Task #${t['task_number'] ?? ''} · ${t['machine_id'] ?? 'Equipment'}',
          '${t['priority'] ?? 'MEDIUM'} · ${t['status'] ?? 'OPEN'}\n${t['title'] ?? ''}',
          icon: Icons.build_circle_outlined,
        );
      },
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Priority extends StatelessWidget {
  const _Priority(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'CRITICAL' => Colors.red.shade800,
      'HIGH' => Colors.deepOrange.shade700,
      'MEDIUM' => Colors.orange.shade800,
      _ => Colors.teal.shade700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        '$value PRIORITY',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.title, this.subtitle, {required this.icon});
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    ),
  );
}

const _button = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.fromHeight(52)),
);
String _date(dynamic value) {
  final parsed = value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
  if (parsed == null) return value?.toString() ?? 'Just now';
  return '${parsed.day}/${parsed.month}/${parsed.year} · ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
