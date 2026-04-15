import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:what_jet/core/theme/app_colors.dart';
import 'package:what_jet/core/theme/app_dimensions.dart';
import '../../data/models/omnichannel_conversation_list_model.dart';

class OmnichannelNewChatPage extends StatefulWidget {
  const OmnichannelNewChatPage({
    super.key,
    required this.items,
    required this.onConversationSelected,
  });

  final List<OmnichannelConversationListItemModel> items;
  final ValueChanged<int> onConversationSelected;

  @override
  State<OmnichannelNewChatPage> createState() => _OmnichannelNewChatPageState();
}

class _OmnichannelNewChatPageState extends State<OmnichannelNewChatPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<_NewChatContactEntry> _customContacts = <_NewChatContactEntry>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_NewChatContactEntry> get _contacts {
    final existing = widget.items
        .map(_NewChatContactEntry.fromConversation)
        .where((entry) => entry.title.trim().isNotEmpty)
        .toList();

    final deduped = <String>{};
    final merged = <_NewChatContactEntry>[
      const _NewChatContactEntry(
        title: 'Nomor Anda (Anda)',
        subtitle: 'Kirim pesan ke diri sendiri',
        avatarLabel: 'A',
        avatarColors: <Color>[Color(0xFF8C6DE9), Color(0xFFB07BFF)],
      ),
      ..._customContacts,
    ];

    for (final entry in existing) {
      final key = entry.title.toLowerCase();
      if (deduped.add(key)) {
        merged.add(entry);
      }
    }

    return merged;
  }

  List<_NewChatContactEntry> get _filteredContacts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _contacts;
    }

    return _contacts.where((entry) {
      return entry.title.toLowerCase().contains(query) ||
          entry.subtitle.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openCreateContactPage() async {
    final createdContact = await Navigator.of(context)
        .push<_CreatedContactDraft>(
          MaterialPageRoute<_CreatedContactDraft>(
            builder: (_) => const OmnichannelCreateContactPage(),
          ),
        );

    if (!mounted || createdContact == null) {
      return;
    }

    setState(() {
      _customContacts.insert(
        0,
        _NewChatContactEntry(
          title: createdContact.fullName,
          subtitle: createdContact.phone,
          avatarLabel: _contactInitial(createdContact.fullName),
          avatarColors: _avatarColorsFor(createdContact.fullName),
        ),
      );
    });

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Kontak ${createdContact.fullName} disimpan.')),
      );
  }

  void _selectConversation(_NewChatContactEntry entry) {
    if (entry.conversationId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Kontak baru tersimpan. Mulai chat backend belum tersedia.',
            ),
          ),
        );
      return;
    }

    widget.onConversationSelected(entry.conversationId!);
    Navigator.of(context).pop();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$feature belum diaktifkan.')));
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: AppColors.surfaceSecondary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.neutral800,
                    iconSize: 28,
                  ),
                  const Expanded(
                    child: Text(
                      'Obrolan baru',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showComingSoon('Menu obrolan'),
                    icon: const Icon(Icons.more_vert_rounded),
                    color: AppColors.neutral800,
                    iconSize: 26,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceTertiary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(fontSize: 17, color: AppColors.neutral800),
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau nomor',
                    hintStyle: TextStyle(
                      fontSize: 17,
                      color: AppColors.neutral400,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.neutral400,
                      size: 24,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
            _NewChatActionTile(
              icon: Icons.group_add_rounded,
              title: 'Grup baru',
              onTap: () => _showComingSoon('Grup baru'),
            ),
            _NewChatActionTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Kontak baru',
              trailing: const Icon(
                Icons.qr_code_2_rounded,
                size: 24,
                color: AppColors.neutral800,
              ),
              onTap: _openCreateContactPage,
            ),
            _NewChatActionTile(
              icon: Icons.groups_2_rounded,
              title: 'Komunitas baru',
              subtitle: 'Satukan grup berdasarkan topik',
              onTap: () => _showComingSoon('Komunitas baru'),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Daftar kontak di WhatsApp',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral400,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(bottom: 18),
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final entry = _filteredContacts[index];
                  return _NewChatContactTile(
                    entry: entry,
                    onTap: () => _selectConversation(entry),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!kIsWeb) {
      return page;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(child: SizedBox(width: 392, child: page.body)),
    );
  }
}

class OmnichannelCreateContactPage extends StatefulWidget {
  const OmnichannelCreateContactPage({super.key});

  @override
  State<OmnichannelCreateContactPage> createState() =>
      _OmnichannelCreateContactPageState();
}

class _OmnichannelCreateContactPageState
    extends State<OmnichannelCreateContactPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _syncToPhone = true;
  String _selectedAccount = 'Akun perangkat';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAccount() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: const Text('Akun perangkat'),
                onTap: () => Navigator.of(context).pop('Akun perangkat'),
              ),
              ListTile(
                title: const Text('Google'),
                onTap: () => Navigator.of(context).pop('Google'),
              ),
            ],
          ),
        );
      },
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() => _selectedAccount = selection);
  }

  void _save() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();

    if (firstName.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Nama depan dan nomor telepon wajib diisi.'),
          ),
        );
      return;
    }

    Navigator.of(context).pop(
      _CreatedContactDraft(
        firstName: firstName,
        lastName: lastName,
        phone: phone.startsWith('+62') ? phone : '+62 $phone',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: AppColors.surfaceSecondary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AppColors.neutral800,
                    iconSize: 28,
                  ),
                  const Expanded(
                    child: Text(
                      'Kontak baru',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: AppColors.neutral800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_2_rounded),
                    color: AppColors.neutral800,
                    iconSize: 24,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: <Widget>[
                    _CreateContactInputRow(
                      icon: Icons.person_outline_rounded,
                      child: _OutlinedField(
                        controller: _firstNameController,
                        hintText: 'Nama depan',
                      ),
                    ),
                    const SizedBox(height: 28),
                    _CreateContactInputRow(
                      icon: null,
                      child: _OutlinedField(
                        controller: _lastNameController,
                        hintText: 'Nama belakang',
                      ),
                    ),
                    const SizedBox(height: 28),
                    _CreateContactInputRow(
                      icon: Icons.call_outlined,
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            flex: 11,
                            child: _CountryCodeField(
                              value: 'ID +62',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 13,
                            child: _OutlinedField(
                              controller: _phoneController,
                              hintText: 'Telepon',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(
                          width: 32,
                          child: Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.sync_rounded,
                              size: 24,
                              color: AppColors.neutral400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Sinkronkan kontak ke\ntelepon',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.neutral800,
                              height: 1.35,
                            ),
                          ),
                        ),
                        Switch(
                          value: _syncToPhone,
                          activeThumbColor: AppColors.white,
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.borderDefault,
                          onChanged: (value) {
                            setState(() => _syncToPhone = value);
                          },
                        ),
                      ],
                    ),
                    if (_syncToPhone) ...<Widget>[
                      const SizedBox(height: 18),
                      Padding(
                        padding: EdgeInsets.only(left: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Sinkronkan ke',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.neutral400,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickAccount,
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.borderDefault,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        _selectedAccount,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: AppColors.neutral800,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AppColors.neutral400,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderRadiusXxxl,
                      ),
                    ),
                    child: const Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!kIsWeb) {
      return page;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Center(child: SizedBox(width: 392, child: page.body)),
    );
  }
}

class _CreateContactInputRow extends StatelessWidget {
  const _CreateContactInputRow({required this.icon, required this.child});

  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 32,
          child: icon == null
              ? const SizedBox.shrink()
              : Icon(icon, color: AppColors.neutral400, size: 24),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _OutlinedField extends StatelessWidget {
  const _OutlinedField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 16, color: AppColors.neutral800),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 16, color: AppColors.neutral400),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _CountryCodeField extends StatelessWidget {
  const _CountryCodeField({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 6, 12, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Negara',
              style: TextStyle(fontSize: 12, color: AppColors.neutral400),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 16, color: AppColors.neutral800),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.neutral400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatActionTile extends StatelessWidget {
  const _NewChatActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.surfacePrimary, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutral800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.neutral400,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _NewChatContactTile extends StatelessWidget {
  const _NewChatContactTile({required this.entry, required this.onTap});

  final _NewChatContactEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: entry.avatarColors,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.avatarLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.surfacePrimary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: AppColors.neutral800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: AppColors.neutral400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderDefault),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatedContactDraft {
  const _CreatedContactDraft({
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  final String firstName;
  final String lastName;
  final String phone;

  String get fullName {
    final parts = <String>[
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(' ');
  }
}

class _NewChatContactEntry {
  const _NewChatContactEntry({
    required this.title,
    required this.subtitle,
    required this.avatarLabel,
    required this.avatarColors,
    this.conversationId,
  });

  factory _NewChatContactEntry.fromConversation(
    OmnichannelConversationListItemModel item,
  ) {
    final name = (item.customerLabel ?? item.title).trim();

    return _NewChatContactEntry(
      title: name.isEmpty ? item.title : name,
      subtitle: item.customerPhone?.trim().isNotEmpty == true
          ? item.customerPhone!.trim()
          : item.preview.trim(),
      avatarLabel: _contactInitial(name.isEmpty ? item.title : name),
      avatarColors: _avatarColorsFor(name.isEmpty ? item.title : name),
      conversationId: item.id,
    );
  }

  final String title;
  final String subtitle;
  final String avatarLabel;
  final List<Color> avatarColors;
  final int? conversationId;
}

String _contactInitial(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return 'C';
  }

  final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (words.length >= 2) {
    final first = words.first.characters.first.toUpperCase();
    final second = words.skip(1).first.characters.first.toUpperCase();
    return '$first$second';
  }

  return text.characters.first.toUpperCase();
}

List<Color> _avatarColorsFor(String value) {
  final text = value.trim();
  final seed = text.isEmpty ? 0 : text.characters.first.codeUnitAt(0);

  switch (seed % 5) {
    case 0:
      return const <Color>[Color(0xFF02A78F), Color(0xFF18C4A7)];
    case 1:
      return const <Color>[Color(0xFF7E57C2), Color(0xFFB06BFF)];
    case 2:
      return const <Color>[Color(0xFF5C6BC0), Color(0xFF7986CB)];
    case 3:
      return const <Color>[Color(0xFF8D6E63), Color(0xFFB1897E)];
    default:
      return const <Color>[Color(0xFF607D8B), Color(0xFF78909C)];
  }
}
