import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../l10n/app_strings.dart';
import '../models/user_settings.dart';
import '../services/user_settings_service.dart';
import '../widgets/modern_surface.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.user,
    required this.localeCode,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.onSignOut,
  });

  final AuthUser? user;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeModeChanged;
  final VoidCallback? onSignOut;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;

  bool _loading = true;
  bool _saving = false;
  UserProfileDraft? _profile;
  List<TrustedContact> _contacts = const <TrustedContact>[];
  String _localeCode = 'en';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _loadState();
  }

  Future<void> _loadState() async {
    final profile = await UserSettingsService.loadProfile(fallbackUser: widget.user);
    final contacts = await UserSettingsService.loadTrustedContacts();
    final localeCode = await UserSettingsService.loadLocaleCode();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _contacts = contacts;
      _localeCode = localeCode;
      _themeMode = widget.themeMode;
      _nameController.text = profile.displayName;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _bioController.text = profile.bio;
      _loading = false;
    });
  }

  Future<void> _saveProfile() async {
    final current = _profile;
    if (current == null) return;

    setState(() {
      _saving = true;
    });

    final updated = UserProfileDraft(
      displayName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
    );

    await UserSettingsService.saveProfile(updated);

    if (!mounted) return;
    setState(() {
      _profile = updated;
      _saving = false;
    });

    final strings = AppStrings(_localeCode);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.profileSaved)));
  }

  Future<void> _resetProfile() async {
    await UserSettingsService.clearProfile();
    final profile = await UserSettingsService.loadProfile(fallbackUser: widget.user);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _nameController.text = profile.displayName;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone;
      _bioController.text = profile.bio;
    });
  }

  Future<void> _setLocale(String code) async {
    if (code == _localeCode) return;
    await UserSettingsService.setLocaleCode(code);
    if (!mounted) return;
    setState(() {
      _localeCode = code;
    });
    widget.onLocaleChanged(code);
  }

  Future<void> _toggleLocale() async {
    await _setLocale(_localeCode == 'en' ? 'sw' : 'en');
  }

  ThemeMode _nextThemeMode(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }

  String _themeLabel(AppStrings strings, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => strings.systemTheme,
      ThemeMode.light => strings.lightTheme,
      ThemeMode.dark => strings.darkTheme,
    };
  }

  Future<void> _cycleThemeMode() async {
    final nextMode = _nextThemeMode(_themeMode);
    await widget.onThemeModeChanged(nextMode);
    if (!mounted) return;
    setState(() {
      _themeMode = nextMode;
    });
  }

  Future<void> _editContact({TrustedContact? existing}) async {
    final strings = AppStrings(_localeCode);
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final relationshipController = TextEditingController(text: existing?.relationship ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    final result = await showDialog<TrustedContact>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(existing == null ? strings.addTrustedContact : strings.editTrustedContact),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: strings.name),
                ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: strings.phoneNumber),
                ),
                TextField(
                  controller: relationshipController,
                  decoration: InputDecoration(labelText: strings.relationship),
                ),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: strings.notes),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.namePhoneRequired)),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(
                  TrustedContact(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    phone: phone,
                    relationship: relationshipController.text.trim(),
                    notes: notesController.text.trim(),
                  ),
                );
              },
              child: Text(strings.save),
            ),
          ],
        );
      },
    );

    if (result == null) return;
    await UserSettingsService.upsertTrustedContact(result);
    final contacts = await UserSettingsService.loadTrustedContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
    });
  }

  Future<void> _removeContact(TrustedContact contact) async {
    await UserSettingsService.deleteTrustedContact(contact.id);
    final contacts = await UserSettingsService.loadTrustedContacts();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_localeCode);
    if (_loading || _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _SectionCard(
          title: strings.accountProfile,
          subtitle: strings.accountProfileSubtitle,
          child: Column(
            children: [
              TextField(controller: _nameController, decoration: InputDecoration(labelText: strings.fullName)),
              const SizedBox(height: 10),
              TextField(controller: _emailController, decoration: InputDecoration(labelText: strings.email)),
              const SizedBox(height: 10),
              TextField(controller: _phoneController, decoration: InputDecoration(labelText: strings.phoneNumber)),
              const SizedBox(height: 10),
              TextField(
                controller: _bioController,
                decoration: InputDecoration(labelText: strings.bioNotes),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _resetProfile,
                      child: Text(strings.reset),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(strings.saveProfile),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: strings.appSettings,
          subtitle: strings.appSettingsSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _toggleLocale,
                icon: const Icon(Icons.language),
                label: Text(_localeCode == 'en' ? strings.useSwahili : strings.useEnglish),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _cycleThemeMode,
                icon: const Icon(Icons.brightness_6_outlined),
                label: Text('${strings.themeMode}: ${_themeLabel(strings, _themeMode)}'),
              ),
              if (widget.onSignOut != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: widget.onSignOut,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                  icon: const Icon(Icons.logout),
                  label: Text(strings.signOut),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: strings.trustedPeople,
          subtitle: strings.trustedPeopleSubtitle,
          child: Column(
            children: [
              if (_contacts.isEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(strings.noTrustedPeople),
                ),
              ..._contacts.map(
                (contact) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TrustedContactTile(
                    contact: contact,
                    onEdit: () => _editContact(existing: contact),
                    onDelete: () => _removeContact(contact),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _editContact(),
                  icon: const Icon(Icons.person_add),
                  label: Text(strings.addTrustedPerson),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: strings.safetyNote,
          subtitle: strings.safetyNoteSubtitle,
          child: Text(strings.sosExplanation),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(widget.subtitle, style: TextStyle(color: Colors.black.withValues(alpha: 0.65))),
                      ],
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: widget.child,
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _TrustedContactTile extends StatelessWidget {
  const _TrustedContactTile({required this.contact, required this.onEdit, required this.onDelete});

  final TrustedContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      onTap: onEdit,
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      backgroundColor: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0E7C7B).withValues(alpha: 0.12),
            child: Text(contact.name.isEmpty ? '?' : contact.name.characters.first.toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(contact.phone),
                if (contact.relationship.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(contact.relationship, style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
                ],
              ],
            ),
          ),
          IconButton(onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
          IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}
