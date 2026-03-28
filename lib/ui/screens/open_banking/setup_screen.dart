import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_strings.dart';
import '../../../services/open_banking/open_banking_providers.dart';
import '../../../services/providers/providers.dart';
import 'connections_screen.dart';

/// 4-step wizard for setting up Enable Banking credentials.
class OpenBankingSetupScreen extends ConsumerStatefulWidget {
  const OpenBankingSetupScreen({super.key});

  @override
  ConsumerState<OpenBankingSetupScreen> createState() => _OpenBankingSetupScreenState();
}

class _OpenBankingSetupScreenState extends ConsumerState<OpenBankingSetupScreen> {
  int _step = 0;
  String _pemPath = '';
  String _appId = '';
  bool _verifying = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.obSetupTitle)),
      body: Stepper(
        currentStep: _step,
        onStepContinue: _step < 3 ? () => setState(() => _step++) : null,
        onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
        controlsBuilder: (context, details) {
          if (_step == 2) return const SizedBox.shrink(); // custom controls
          if (_step == 3) return const SizedBox.shrink(); // final step
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(s.next),
                ),
                if (details.onStepCancel != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: Text(s.back),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: Text(s.obStep1Title),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: _buildStep1(s),
          ),
          Step(
            title: Text(s.obStep2Title),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: _buildStep2(s),
          ),
          Step(
            title: Text(s.obStep3Title),
            isActive: _step >= 2,
            state: _step > 2 ? StepState.complete : StepState.indexed,
            content: _buildStep3(s, theme),
          ),
          Step(
            title: Text(s.obStep4Title),
            isActive: _step >= 3,
            state: StepState.indexed,
            content: _buildStep4(s),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.obStep1Desc),
        const SizedBox(height: 12),
        Text(s.obStep1Instructions, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(s.obCreateAccount),
          onPressed: () => launchUrl(
            Uri.parse('https://enablebanking.com/sign-in/'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.obStep2Desc),
        const SizedBox(height: 12),
        Text(s.obStep2Instructions, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(s.obOpenDashboard),
          onPressed: () => launchUrl(
            Uri.parse('https://enablebanking.com/cp/'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(AppStrings s, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.obStep3Desc),
        const SizedBox(height: 16),
        // PEM file picker
        Row(
          children: [
            Expanded(
              child: Text(
                _pemPath.isEmpty ? s.obNoPemSelected : p.basename(_pemPath),
                style: TextStyle(
                  color: _pemPath.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _pickPemFile,
              child: Text(s.obSelectPem),
            ),
          ],
        ),
        if (_pemPath.isNotEmpty) ...[
          const SizedBox(height: 12),
          // App ID (auto-detected from filename)
          TextField(
            decoration: InputDecoration(
              labelText: s.obAppIdLabel,
              helperText: s.obAppIdHelper,
              border: const OutlineInputBorder(),
            ),
            controller: TextEditingController(text: _appId),
            onChanged: (v) => _appId = v,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: _pemPath.isNotEmpty && _appId.isNotEmpty && !_verifying
                  ? _verifyAndSave
                  : null,
              child: _verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(s.obVerifyAndSave),
            ),
            if (_step > 0) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _step--),
                child: Text(s.back),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStep4(AppStrings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(s.obSetupComplete, style: const TextStyle(fontSize: 16))),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.account_balance),
          label: Text(s.obConnectFirstBank),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const OpenBankingConnectionsScreen()),
            );
          },
        ),
      ],
    );
  }

  Future<void> _pickPemFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pem'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _pemPath = path;
      _error = null;
      // Try to extract app ID from filename (UUID format)
      final basename = p.basenameWithoutExtension(path);
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      if (uuidRegex.hasMatch(basename)) {
        _appId = basename;
      }
    });
  }

  Future<void> _verifyAndSave() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      // Copy PEM to config dir for persistence
      final configDir = Directory(
        p.join(
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.',
          '.config', 'FinanceCopilot',
        ),
      );
      if (!await configDir.exists()) await configDir.create(recursive: true);
      final destPath = p.join(configDir.path, '$_appId.pem');
      await File(_pemPath).copy(destPath);

      final service = ref.read(enableBankingServiceProvider);
      await service.setupAndVerify(appId: _appId, privateKeyPath: destPath);

      // Update provider
      ref.invalidate(openBankingConfiguredProvider);
      ref.read(openBankingConfigProvider.notifier).state = service.config;

      if (mounted) setState(() => _step = 3);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}
