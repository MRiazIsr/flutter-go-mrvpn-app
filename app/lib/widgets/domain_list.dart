import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Widget for managing a list of domains in split tunnel domain mode.
///
/// Provides a text field to add new domains, a scrollable list of existing
/// domains with delete buttons, and import/export actions.
class DomainList extends StatefulWidget {
  /// Current list of domain patterns.
  final List<String> domains;

  /// Called when a domain is added.
  final ValueChanged<String>? onAdd;

  /// Called when a domain is removed.
  final ValueChanged<String>? onRemove;

  /// Called when the user taps "Import".
  final VoidCallback? onImport;

  /// Called when the user taps "Export".
  final VoidCallback? onExport;

  const DomainList({
    super.key,
    required this.domains,
    this.onAdd,
    this.onRemove,
    this.onImport,
    this.onExport,
  });

  @override
  State<DomainList> createState() => _DomainListState();
}

class _DomainListState extends State<DomainList> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormFieldState<String>>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static final _domainRegex = RegExp(
    r'^(\*\.)?([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)*[a-z0-9]([a-z0-9\-]*[a-z0-9])?$',
  );

  void _addDomain() {
    var domain = _controller.text.trim();
    if (domain.isEmpty) return;

    // Strip protocol (https://, http://) and path if user pasted a URL.
    domain = domain.replaceFirst(RegExp(r'^https?://'), '');
    // Remove trailing path/slash
    final slashIdx = domain.indexOf('/');
    if (slashIdx != -1) {
      domain = domain.substring(0, slashIdx);
    }
    // Remove port if present
    final colonIdx = domain.indexOf(':');
    if (colonIdx != -1) {
      domain = domain.substring(0, colonIdx);
    }
    domain = domain.trim().toLowerCase();

    if (domain.isEmpty || domain.length > 253) return;

    // Validate domain format: letters, digits, hyphens, dots, optional wildcard prefix
    if (!_domainRegex.hasMatch(domain)) {
      _formKey.currentState?.validate();
      return;
    }

    widget.onAdd?.call(domain);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add domain input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: _formKey,
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Add domain (e.g. example.com)',
                  isDense: true,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    var cleaned = value.trim().toLowerCase();
                    cleaned = cleaned.replaceFirst(RegExp(r'^https?://'), '');
                    final slash = cleaned.indexOf('/');
                    if (slash != -1) cleaned = cleaned.substring(0, slash);
                    final colon = cleaned.indexOf(':');
                    if (colon != -1) cleaned = cleaned.substring(0, colon);
                    if (cleaned.length > 253 ||
                        !_domainRegex.hasMatch(cleaned)) {
                      return 'Enter a valid domain';
                    }
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _addDomain(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addDomain,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              tooltip: 'Add domain',
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Domain list
        Expanded(
          child: widget.domains.isEmpty
              ? Center(
                  child: Text(
                    'No domains added',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.domains.length,
                  itemBuilder: (context, index) {
                    final domain = widget.domains[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.language,
                        size: 20,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                      title: Text(
                        domain,
                        style: theme.textTheme.bodyMedium,
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => widget.onRemove?.call(domain),
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),

        // Import / Export buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              label: const Text('Import'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: widget.onExport,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
