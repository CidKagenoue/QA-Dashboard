import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/notification_navigation_service.dart';
import '../services/auth_service.dart';
import '../models/notification_setting.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late NotificationNavigationService _service;
  String? _error;
    List<NotificationSetting> _settings = [];
    List<NotificationSetting> _uiSettings = [];
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);
    _service = NotificationNavigationService(
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
          '${e['module']}_${e['type']}': NotificationSetting.fromJson(e as Map<String, dynamic>)
      };
      // Altijd layout tonen: dummy data als basis, status uit backend indien aanwezig
      setState(() {
        _settings = _dummySettings.map((dummy) {
          final key = '${_enumModule(dummy.module)}_${_enumType(dummy.type)}';
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
      case 'WHS-Tours': return 'WHS_TOURS';
      case 'OVA': return 'OVA';
      case 'JAP': return 'JAP';
      case 'Onderhoud Keuringen': return 'MAINTENANCE';
      default: return label;
    }
  }
  String _enumType(String label) {
    switch (label) {
      case 'Nieuwe Taak': return 'WHS_NEW_TASK';
      case 'Commentaar op Taak': return 'WHS_COMMENT';
      case 'Nieuwe Melding': return 'WHS_NEW_REPORT';
      case 'Naderende deadline': return 'OVA_DEADLINE';
      case 'Nieuwe actie toegewezen': return 'OVA_NEW_ACTION';
      case 'Ticket aangemaakt': return 'OVA_TICKET_CREATED';
      case 'OVA 1': return 'OVA_1';
      case 'OVA 2': return 'OVA_2';
      case 'OVA 3': return 'OVA_3';
      case 'Nieuwe JAP/GPP': return 'JAP_NEW';
      case 'Comentaar': return 'JAP_COMMENT';
      case 'Status verandering': return 'JAP_STATUS_CHANGE';
      case 'Keuren vóór nadert': return 'MAINTENANCE_DUE';
      case 'Status verandering': return 'MAINTENANCE_STATUS_CHANGE';
      default: return label;
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
        uniqueSettings['${_enumModule(e.module)}_${_enumType(e.type)}'] = e;
      }
      await _service.updateSettings({
        'settings': uniqueSettings.values.map((e) => {
          'module': _enumModule(e.module),
          'type': _enumType(e.type),
          'enabled': e.enabled,
          'email': e.email,
        }).toList(),
      });
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Instellingen opgeslagen')),
      );
    } catch (e) {
      setState(() {
        _error = 'Fout bij opslaan van instellingen';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dummy data fallback als API faalt
    final List<NotificationSetting> settings = _uiSettings.isEmpty ? _dummySettings : _uiSettings;

    // Groepeer per module
    final Map<String, List<NotificationSetting>> moduleMap = {};
    for (final s in settings) {
      moduleMap.putIfAbsent(s.module, () => []).add(s);
    }

    // Algemene e-mail toggle (dummy: als één setting email=true, dan aan)
    bool emailAll = settings.any((s) => s.email);

    return LayoutBuilder(
      builder: (context, constraints) {
        final moduleEntries = moduleMap.entries.toList();
        final int moduleCount = moduleEntries.length;
        final double minTileWidth = 220;
        final double spacing = 24;
        // Bereken hoeveel tegels er in de breedte passen
        int tilesPerRow = (constraints.maxWidth / (minTileWidth + spacing)).floor();
        tilesPerRow = tilesPerRow.clamp(1, moduleCount);

        // Gebruik een Wrap zodat de cards automatisch afbreken naar een nieuwe regel
        const double cardWidth = 260;
        const double newSpacing = 16;
        final Widget dashboardTiles = Wrap(
          spacing: newSpacing,
          runSpacing: newSpacing,
          children: moduleEntries.map((entry) {
            final module = entry.key;
            final items = entry.value;
            final icon = _moduleIcon(module);
            return SizedBox(
              width: cardWidth,
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 28, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(module, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      ...items.map((s) => Row(
                        children: [
                          Expanded(
                            child: Text(_notificationTypeLabel(s), style: const TextStyle(fontSize: 15)),
                          ),
                          Switch(
                            value: s.enabled,
                            onChanged: (val) {
                              setState(() {
                                _uiSettings = List<NotificationSetting>.from(settings.map((item) =>
                                  (item.module == s.module && item.type == s.type)
                                    ? NotificationSetting(
                                        module: item.module,
                                        type: item.type,
                                        enabled: val,
                                        email: item.email,
                                      )
                                    : item
                                ));
                              });
                            },
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Algemeen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Checkbox(
                    value: emailAll,
                    onChanged: (val) {
                      setState(() {
                        _uiSettings = List<NotificationSetting>.from(settings.map((s) =>
                          NotificationSetting(
                            module: s.module,
                            type: s.type,
                            enabled: s.enabled,
                            email: val ?? false,
                          )
                        ));
                      });
                    },
                  ),
                  const Text('Stuur meldingen via E-Mail', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              dashboardTiles,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _saving ? null : _saveSettings,
                      child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Opslaan'),
                    ),
                    const SizedBox(width: 16),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Dummy data voor layout preview
  List<NotificationSetting> get _dummySettings => [
    NotificationSetting(module: 'WHS-Tours', type: 'Nieuwe Taak', enabled: true, email: false),
    NotificationSetting(module: 'WHS-Tours', type: 'Commentaar op Taak', enabled: false, email: false),
    NotificationSetting(module: 'WHS-Tours', type: 'Nieuwe Melding', enabled: true, email: false),
    NotificationSetting(module: 'OVA', type: 'Naderende deadline', enabled: true, email: true),
    NotificationSetting(module: 'OVA', type: 'Nieuwe actie toegewezen', enabled: true, email: false),
    NotificationSetting(module: 'OVA', type: 'Ticket aangemaakt', enabled: false, email: false),
    NotificationSetting(module: 'OVA', type: 'OVA 1', enabled: false, email: false),
    NotificationSetting(module: 'OVA', type: 'OVA 2', enabled: false, email: false),
    NotificationSetting(module: 'OVA', type: 'OVA 3', enabled: false, email: false),
    NotificationSetting(module: 'JAP', type: 'Nieuwe JAP/GPP', enabled: true, email: false),
    NotificationSetting(module: 'JAP', type: 'Comentaar', enabled: true, email: false),
    NotificationSetting(module: 'JAP', type: 'Status verandering', enabled: true, email: false),
    NotificationSetting(module: 'Onderhoud Keuringen', type: 'Keuren vóór nadert', enabled: true, email: false),
    NotificationSetting(module: 'Onderhoud Keuringen', type: 'Status verandering', enabled: false, email: false),
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
    if (s.module == 'Onderhoud Keuringen' && s.type == 'Keuren vóór nadert') {
      return 'Keuren vóór nadert';
    }
    return s.type;
  }
}
