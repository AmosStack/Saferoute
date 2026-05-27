import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../l10n/app_strings.dart';
import '../models/user_settings.dart';
import '../services/user_settings_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    super.key,
    required this.user,
    required this.localeCode,
    required this.onLocaleChanged,
  });

  final AuthUser? user;
  final String localeCode;
  final ValueChanged<String> onLocaleChanged;

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
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(strings.english),
                  selected: _localeCode == 'en',
                  onSelected: (_) => _setLocale('en'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: Text(strings.swahili),
                  selected: _localeCode == 'sw',
                  onSelected: (_) => _setLocale('sw'),
                ),
              ),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
          const SizedBox(height: 14),
          child,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
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
