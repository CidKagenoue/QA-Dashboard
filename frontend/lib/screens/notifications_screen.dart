import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_settings_service.dart';
import '../services/auth_service.dart';
import '../models/notification_setting.dart';
import '../widgets/design/design_system.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationSettingsService _service;
  String? _error;
  List<NotificationSetting> _settings = [];
  List<NotificationSetting> _uiSettings = [];
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = NotificationSettingsService(
      baseUrl: ApiService.baseUrl,
      authService: authService,
    );
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() {
      _error = null;
    });
    try {
      final data = await _service.fetchSettings();
      final settingsList = (data['settings'] ?? data) as List<dynamic>;
      // Map backend data naar een map voor snelle lookup
      final backendMap = {
        for (var e in settingsList)
          '${e['module']}_${e['type']}': NotificationSetting.fromJson(
            e as Map<String, dynamic>,
          ),
      };
      // Altijd layout tonen: dummy data als basis, status uit backend indien aanwezig
      setState(() {
        _settings = _dummySettings.map((dummy) {
          final key =
              '${_enumModule(dummy.module)}_${_enumType(dummy.module, dummy.type)}';
          if (backendMap[key] != null) {
            return dummy.copyWith(
              enabled: backendMap[key]!.enabled,
              email: backendMap[key]!.email,
            );
          }
          return dummy;
        }).toList();
        // Maak een kopie voor de UI die direct aangepast mag worden
        _uiSettings = List<NotificationSetting>.from(_settings);
      });
    } catch (e) {
      // Alleen bij netwerkfout een foutmelding tonen, layout blijft altijd zichtbaar
      setState(() {
        _error = 'Fout bij laden van instellingen';
      });
    }
  }

  // Helper om frontend label naar backend enum te mappen
  String _enumModule(String label) {
    switch (label) {
      case 'WHS-Tours':
        return 'WHS_TOURS';
      case 'OVA':
        return 'OVA';
      case 'JAP':
        return 'JAP';
      case 'Onderhoud Keuringen':
        return 'MAINTENANCE';
      default:
        return label;
    }
  }

  String _enumType(String module, String label) {
    switch (module) {
      case 'JAP':
        switch (label) {
          case 'Nieuwe JAP/GPP':
            return 'JAP_NEW';
          case 'Comentaar':
            return 'JAP_COMMENT';
          case 'Status verandering':
            return 'JAP_STATUS_CHANGE';
        }
        break;
      case 'Onderhoud Keuringen':
        switch (label) {
          case 'Nieuwe onderhoud/keuring':
            return 'MAINTENANCE_NEW';
          case 'Keuren vóór nadert':
            return 'MAINTENANCE_DUE';
          case 'Status verandering':
            return 'MAINTENANCE_STATUS_CHANGE';
        }
        break;
    }

    switch (label) {
      case 'Nieuwe Taak':
        return 'WHS_NEW_TASK';
      case 'Commentaar op Taak':
        return 'WHS_COMMENT';
      case 'Nieuwe Melding':
        return 'WHS_NEW_REPORT';
      case 'Naderende deadline':
        return 'OVA_DEADLINE';
      case 'Nieuwe actie toegewezen':
        return 'OVA_NEW_ACTION';
      case 'Ticket aangemaakt':
        return 'OVA_TICKET_CREATED';
      case 'OVA 1':
        return 'OVA_1';
      case 'OVA 2':
        return 'OVA_2';
      case 'OVA 3':
        return 'OVA_3';
      case 'Nieuwe JAP/GPP':
        return 'JAP_NEW';
      case 'Comentaar':
        return 'JAP_COMMENT';
      case 'Nieuwe onderhoud/keuring':
        return 'MAINTENANCE_NEW';
      case 'Keuren vóór nadert':
        return 'MAINTENANCE_DUE';
      default:
        return label;
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uniqueSettings = <String, NotificationSetting>{};
      for (var e in _uiSettings) {
        uniqueSettings['${_enumModule(e.module)}_${_enumType(e.module, e.type)}'] =
            e;
      }
      await _service.updateSettings({
        'settings': uniqueSettings.values
            .map(
              (e) => {
                'module': _enumModule(e.module),
                'type': _enumType(e.module, e.type),
                'enabled': e.enabled,
                'email': e.email,
              },
            )
            .toList(),
      });
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Instellingen opgeslagen')));
    } catch (e) {
      setState(() {
        _error = 'Fout bij opslaan van instellingen';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<NotificationSetting> settings =
        _uiSettings.isEmpty ? _dummySettings : _uiSettings;

    final Map<String, List<NotificationSetting>> moduleMap = {};
    for (final s in settings) {
      moduleMap.putIfAbsent(s.module, () => []).add(s);
    }

    final bool emailAll = settings.any((s) => s.email);

    return Container(
      color: kBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(kRadius2xl),
            border: Border.all(color: kBorder),
          ),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBreadcrumb(
                  segments: ['Instellingen', 'Meldingen']),
              const SizedBox(height: 16),
              const Text(
                'Meldingen',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kies per module welke meldingen je ontvangt en of ze ook per e-mail worden verzonden.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              AppSectionPanel(
                title: 'Algemene voorkeur',
                icon: Icons.tune_rounded,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Stuur meldingen ook per e-mail',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Schakel deze optie in om alle ingeschakelde meldingen ook in je inbox te ontvangen.',
                            style: TextStyle(
                              fontSize: 13,
                              color: kTextTertiary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Switch(
                      value: emailAll,
                      onChanged: (val) {
                        setState(() {
                          _uiSettings = List<NotificationSetting>.from(
                            settings.map(
                              (s) => NotificationSetting(
                                module: s.module,
                                type: s.type,
                                enabled: s.enabled,
                                email: val,
                              ),
                            ),
                          );
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: kBrandGreenSubtle,
                      borderRadius: BorderRadius.circular(kRadiusSm),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_outlined,
                        size: 18, color: kBrandGreenDeep),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Per module',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: moduleMap.entries.map((entry) {
                  final module = entry.key;
                  final items = entry.value;
                  return SizedBox(
                    width: 320,
                    child: _ModuleNotificationsCard(
                      module: module,
                      items: items,
                      icon: _moduleIcon(module),
                      onToggleEnabled: (s, val) {
                        setState(() {
                          _uiSettings =
                              List<NotificationSetting>.from(settings.map(
                            (item) => (item.module == s.module &&
                                    item.type == s.type)
                                ? NotificationSetting(
                                    module: item.module,
                                    type: item.type,
                                    enabled: val,
                                    email: item.email,
                                  )
                                : item,
                          ));
                        });
                      },
                      onToggleEmail: (s, val) {
                        setState(() {
                          _uiSettings =
                              List<NotificationSetting>.from(settings.map(
                            (item) => (item.module == s.module &&
                                    item.type == s.type)
                                ? NotificationSetting(
                                    module: item.module,
                                    type: item.type,
                                    enabled: item.enabled,
                                    email: val,
                                  )
                                : item,
                          ));
                        });
                      },
                      labelFor: _notificationTypeLabel,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveSettings,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Wijzigingen opslaan'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(width: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: kDanger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dummy data voor layout preview
  List<NotificationSetting> get _dummySettings => [
    NotificationSetting(
      module: 'WHS-Tours',
      type: 'Nieuwe Taak',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'WHS-Tours',
      type: 'Commentaar op Taak',
      enabled: false,
      email: false,
    ),
    NotificationSetting(
      module: 'WHS-Tours',
      type: 'Nieuwe Melding',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'OVA',
      type: 'Naderende deadline',
      enabled: true,
      email: true,
    ),
    NotificationSetting(
      module: 'OVA',
      type: 'Nieuwe actie toegewezen',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'OVA',
      type: 'Ticket aangemaakt',
      enabled: false,
      email: false,
    ),
    NotificationSetting(
      module: 'OVA',
      type: 'OVA 1',
      enabled: false,
      email: false,
    ),
    NotificationSetting(
      module: 'OVA',
      type: 'OVA 2',
      enabled: false,
      email: false,
    ),
    NotificationSetting(
      module: 'OVA',
      type: 'OVA 3',
      enabled: false,
      email: false,
    ),
    NotificationSetting(
      module: 'JAP',
      type: 'Nieuwe JAP/GPP',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'JAP',
      type: 'Comentaar',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'JAP',
      type: 'Status verandering',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'Onderhoud Keuringen',
      type: 'Nieuwe onderhoud/keuring',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'Onderhoud Keuringen',
      type: 'Keuren vóór nadert',
      enabled: true,
      email: false,
    ),
    NotificationSetting(
      module: 'Onderhoud Keuringen',
      type: 'Status verandering',
      enabled: true,
      email: false,
    ),
  ];

  IconData _moduleIcon(String module) {
    switch (module) {
      case 'WHS-Tours':
        return Icons.home_outlined;
      case 'OVA':
        return Icons.info_outline;
      case 'JAP':
        return Icons.description_outlined;
      case 'Onderhoud Keuringen':
        return Icons.build_outlined;
      default:
        return Icons.notifications;
    }
  }

  String _notificationTypeLabel(NotificationSetting s) {
    // Je kunt hier per type extra info toevoegen zoals in het voorbeeld
    if (s.module == 'OVA' && s.type == 'Naderende deadline') {
      return 'Naderende deadline (Eigen acties)';
    }
    if (s.module == 'JAP' && s.type == 'Comentaar') {
      return 'Comentaar (in afdeling)';
    }
    if (s.module == 'JAP' && s.type == 'Status verandering') {
      return 'Status verandering (in afdeling)';
    }
    if (s.module == 'Onderhoud Keuringen' &&
        s.type == 'Nieuwe onderhoud/keuring') {
      return 'Nieuwe onderhoud/keuring';
    }
    if (s.module == 'Onderhoud Keuringen' && s.type == 'Keuren vóór nadert') {
      return 'Keuren vóór nadert';
    }
    if (s.module == 'Onderhoud Keuringen' && s.type == 'Status verandering') {
      return 'Status verandering';
    }
    return s.type;
  }
}

class _ModuleNotificationsCard extends StatelessWidget {
  const _ModuleNotificationsCard({
    required this.module,
    required this.items,
    required this.icon,
    required this.onToggleEnabled,
    required this.onToggleEmail,
    required this.labelFor,
  });

  final String module;
  final List<NotificationSetting> items;
  final IconData icon;
  final void Function(NotificationSetting, bool) onToggleEnabled;
  final void Function(NotificationSetting, bool) onToggleEmail;
  final String Function(NotificationSetting) labelFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kBrandGreenSoft,
                  borderRadius: BorderRadius.circular(kRadiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: kBrandGreenDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(items.length, (i) {
            final s = items[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: s.enabled ? kBrandGreenSubtle : kSurfaceMuted,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(
                    color: s.enabled ? kBrandGreenSoft : kBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            labelFor(s),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: s.enabled ? kTextPrimary : kTextSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: s.enabled,
                            onChanged: (val) => onToggleEnabled(s, val),
                          ),
                        ),
                      ],
                    ),
                    if (s.enabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.mail_outline_rounded,
                                size: 14, color: kTextTertiary),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Ook per e-mail',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kTextTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: s.email,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) => onToggleEmail(s, val),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
