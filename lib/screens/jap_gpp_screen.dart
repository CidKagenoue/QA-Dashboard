// lib/screens/jap_gpp_screen.dart

import 'package:flutter/material.dart';
import 'package:qa_dashboard/services/jap_gpp_api_service.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../models/jap_gpp_entry.dart';
import 'jap_detail_screen.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class JapGppScreen extends StatefulWidget {
  final String token;

  const JapGppScreen({
    super.key,
    required this.token,
  });

  @override
  State<JapGppScreen> createState() => _JapGppScreenState();
}

class _JapGppScreenState extends State<JapGppScreen> {
  // ── data ──────────────────────────────────────────────────────────────────
  List<JapEntry> _allEntries = [];
  List<JapEntry> _filtered = [];
  bool _loading = true;
  String? _error;

  // ── search ────────────────────────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _gppSearchController = TextEditingController();
  List<GppEntry> _filteredGpp = [];
  String? _filterGppDomein;

  String? _filterPriority;
  int? _filterYear;

  // ── active tab (JAP | GPP) ────────────────────────────────────────────────
  int _tabIndex = 0;
  List<GppEntry> _allGppEntries = [];

  Future<void> _loadGppEntries() async {
    try {
      final entries = await JapApiService.fetchGppEntries(token: widget.token);
      setState(() => _allGppEntries = entries);
      _applyGppFilter(); // ← voeg toe
    } catch (e) {
      // optioneel: fout tonen
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadGppEntries();
    _searchController.addListener(_applyFilter);
    _gppSearchController.addListener(_applyGppFilter); // ← voeg toe
  }

  @override
  void dispose() {
    _searchController.dispose();
    _gppSearchController.dispose(); // ← voeg toe
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────
  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await JapApiService.fetchJapEntries(
        token: widget.token,
      );

      setState(() {
        _allEntries = entries;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    var result = _allEntries.where((e) {
      if (query.isNotEmpty) {
        final matchesQuery =
            e.goalMeasure.toLowerCase().contains(query) ||
            e.domain.toLowerCase().contains(query) ||
            e.year.toString().contains(query);
        if (!matchesQuery) return false;
      }
      if (_filterPriority != null) {
        final priorityMatch = switch (_filterPriority) {
          'hoog' => e.priority == JapPriority.high,
          'middel' => e.priority == JapPriority.medium,
          'laag' => e.priority == JapPriority.low,
          _ => true,
        };
        if (!priorityMatch) return false;
      }
      if (_filterYear != null && e.year != _filterYear) return false;
      return true;
    }).toList();

    setState(() => _filtered = result);
  }

  void _applyGppFilter() {
    final query = _gppSearchController.text.toLowerCase();
    var result = _allGppEntries.where((e) {
      if (query.isNotEmpty) {
        final matchesQuery =
            e.goalMeasure.toLowerCase().contains(query) ||
            e.domain.toLowerCase().contains(query) ||
            e.yearLabel.toLowerCase().contains(query);
        if (!matchesQuery) return false;
      }
      if (_filterGppDomein != null && e.domain != _filterGppDomein) return false;
      return true;
    }).toList();

    setState(() => _filteredGpp = result);
  }

  void _showFilterSheet() {
    final years = _allEntries.map((e) => e.year).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filteren',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF243022),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterPriority = null;
                            _filterYear = null;
                          });
                          _applyFilter();
                          setSheetState(() {});
                        },
                        child: const Text(
                          'Wis filters',
                          style: TextStyle(color: Color(0xFF6B7A62)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Prioriteit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D5548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Hoge prioriteit',
                        selected: _filterPriority == 'hoog',
                        onTap: () {
                          setState(() => _filterPriority =
                              _filterPriority == 'hoog' ? null : 'hoog');
                          _applyFilter();
                          setSheetState(() {});
                        },
                      ),
                      _FilterChip(
                        label: 'Middelhoge prioriteit',
                        selected: _filterPriority == 'middel',
                        onTap: () {
                          setState(() => _filterPriority =
                              _filterPriority == 'middel' ? null : 'middel');
                          _applyFilter();
                          setSheetState(() {});
                        },
                      ),
                      _FilterChip(
                        label: 'Lage prioriteit',
                        selected: _filterPriority == 'laag',
                        onTap: () {
                          setState(() => _filterPriority =
                              _filterPriority == 'laag' ? null : 'laag');
                          _applyFilter();
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Jaar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D5548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: years.map((year) {
                      return _FilterChip(
                        label: year.toString(),
                        selected: _filterYear == year,
                        onTap: () {
                          setState(() =>
                              _filterYear = _filterYear == year ? null : year);
                          _applyFilter();
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Toepassen'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showGppFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filteren',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF243022),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _filterGppDomein = null);
                          _applyGppFilter();
                          setSheetState(() {});
                        },
                        child: const Text(
                          'Wis filters',
                          style: TextStyle(color: Color(0xFF6B7A62)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Domein',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4D5548),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Arbeidsveiligheid', 'Welzijnbeleid'].map((domein) {
                      return _FilterChip(
                        label: domein,
                        selected: _filterGppDomein == domein,
                        onTap: () {
                          setState(() => _filterGppDomein =
                              _filterGppDomein == domein ? null : domein);
                          _applyGppFilter();
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Toepassen'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateJapDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: _CreateJapForm(
            token: widget.token,
            onSaved: () async {
              await _loadEntries();
              try {
                await context.read<NotificationService>().loadNotifications(limit: 50);
                await context.read<NotificationService>().refreshUnreadCount();
              } catch (_) {}
            },
          ),
        );
      },
    );
  }

  void _showCreateGppDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: _CreateGppForm(
            token: widget.token,
            onSaved: () async {
              await _loadGppEntries();
              try {
                await context.read<NotificationService>().loadNotifications(limit: 50);
                await context.read<NotificationService>().refreshUnreadCount();
              } catch (_) {}
            },
          ),
        );
      },
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumb(),
        _buildHeader(),
        _buildTabBar(),
        const SizedBox(height: 8),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Text('Dashboard', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
          ),
          Text('JAP & GPP', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Text('JAP & GPP', style: Theme.of(context).textTheme.headlineMedium),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _TabButton(
                  label: 'JAP',
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 4),
                _TabButton(
                  label: 'GPP',
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_tabIndex == 1) return _buildGppBody();

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadEntries,
              child: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildToolbar(),
          const SizedBox(height: 12),
          Expanded(child: _buildTable()),
        ],
      ),
    );
  }

  Widget _buildGppBody() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _gppSearchController,
                  decoration: InputDecoration(
                    hintText: 'Zoeken',
                    hintStyle: const TextStyle(fontSize: 14),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFFD7DBD2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFFD7DBD2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: const BorderSide(color: Color(0xFF8CC63F), width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _showGppFilterSheet,
                icon: const Icon(Icons.filter_alt_outlined),
                color: const Color(0xFF6B7A62),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: _showCreateGppDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nieuw'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8CC63F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E9DD)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(32),
                      1: FixedColumnWidth(120),
                      2: FlexColumnWidth(3),
                      3: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE4E9DD))),
                        ),
                        children: [
                          const SizedBox(height: 44),
                          _buildHeaderCell('Periode'),
                          _buildHeaderCell('Doelstelling – maatregel'),
                          _buildHeaderCell('Domein', isLast: true),
                        ],
                      ),
                      ..._filteredGpp.map((entry) => TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF0F2EC))),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
                            child: Icon(Icons.insert_drive_file_outlined, size: 18, color: Colors.grey[400]),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            child: Text(
                              entry.yearLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF243022)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            child: Text(
                              entry.goalMeasure,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            child: Text(
                              entry.domain,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4D5548)),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        const Spacer(),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Zoeken',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Color(0xFFD7DBD2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Color(0xFFD7DBD2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Color(0xFF8CC63F), width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _showFilterSheet,
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: 'Filteren',
          color: const Color(0xFF6B7A62),
        ),
        const SizedBox(width: 4),
        ElevatedButton.icon(
          onPressed: _showCreateJapDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nieuw'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CC63F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E9DD)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(32),
              1: FixedColumnWidth(90),
              2: FlexColumnWidth(3),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(1.6),
              5: FlexColumnWidth(1.6),
            },
            children: [
              _buildHeaderRow(),
              ..._filtered.map(_buildDataRow),
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE4E9DD))),
      ),
      children: [
        const SizedBox(height: 44),
        _buildHeaderCell('Jaar'),
        _buildHeaderCell('Doelstelling – maatregel'),
        _buildHeaderCell('Domein'),
        _buildHeaderCell('Prioriteit'),
        _buildHeaderCell('Realisatie', isLast: true),
      ],
    );
  }

  Widget _buildHeaderCell(String label, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(left: 8, right: isLast ? 16 : 8, top: 12, bottom: 12),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7A62)),
      ),
    );
  }

  TableRow _buildDataRow(JapEntry entry) {
    void openDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JapDetailScreen(entry: entry, token: widget.token),
        ),
      );
    }

    Widget tappable(Widget child) => GestureDetector(onTap: openDetail, child: child);

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F2EC))),
      ),
      children: [
        tappable(Padding(
          padding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
          child: Icon(Icons.insert_drive_file_outlined, size: 18, color: Colors.grey[400]),
        )),
        tappable(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(entry.yearLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF243022))),
        )),
        tappable(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(entry.goalMeasure,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E))),
        )),
        tappable(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(entry.domain,
              style: const TextStyle(fontSize: 13, color: Color(0xFF4D5548))),
        )),
        tappable(Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: _PriorityBadge(priority: entry.priority),
        )),
        tappable(Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: _RealisatieLabel(realisatie: entry.realisation),
        )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TabButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? const Color(0xFF8CC63F) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? const Color(0xFF243022)
                : (onTap == null ? const Color(0xFFBBC3B4) : const Color(0xFF6B7A62)),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final JapPriority priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (priority) {
      JapPriority.high => ('Hoge prioriteit', const Color(0xFFFFEDED), const Color(0xFFD32F2F)),
      JapPriority.medium => ('Middelhoge prioriteit', const Color(0xFFFFF8E1), const Color(0xFFF57F17)),
      JapPriority.low => ('Lage prioriteit', const Color(0xFFF1F1F1), const Color(0xFF757575)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _RealisatieLabel extends StatelessWidget {
  final JapRealisation realisatie;

  const _RealisatieLabel({required this.realisatie});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (realisatie) {
      JapRealisation.inProgress => ('In Uitvoering', const Color(0xFF1565C0)),
      JapRealisation.completed => ('Uitgevoerd', const Color(0xFF2E7D32)),
      JapRealisation.notYetCompleted => ('Nog niet uitgevoerd', const Color(0xFFD32F2F)),
      JapRealisation.fillIn => ('Vul aan', const Color(0xFF6B7A62)),
    };

    return Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF4D9) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? const Color(0xFF8CC63F) : const Color(0xFFD7DBD2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? const Color(0xFF4A7A1E) : const Color(0xFF4D5548),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forms
// ---------------------------------------------------------------------------

class _CreateJapForm extends StatefulWidget {
  final String token;
  final VoidCallback onSaved;

  const _CreateJapForm({required this.token, required this.onSaved});

  @override
  State<_CreateJapForm> createState() => _CreateJapFormState();
}

class _CreateJapFormState extends State<_CreateJapForm> {
  final _doelstellingController = TextEditingController();
  final _opmerkingController = TextEditingController();

  String _domein = 'Arbeidsveiligheid';
  String _risico = 'Algemeen';
  String _uitvoerder = '';
  String _prioriteit = 'Lage prioriteit';
  String _realisatie = 'Uitgevoerd';
  DateTime? _startDate;

  @override
  void dispose() {
    _doelstellingController.dispose();
    _opmerkingController.dispose();
    super.dispose();
  }

  String _prioriteitToApiString(String label) {
    switch (label) {
      case 'Hoge prioriteit': return 'hoog';
      case 'Middelhoge prioriteit': return 'middel';
      default: return 'laag';
    }
  }

  String _realisatieToApiString(String label) {
    switch (label) {
      case 'In uitvoering': return 'in_uitvoering';
      case 'Nog niet uitgevoerd': return 'neg_niet_uitgevoerd';
      default: return 'uitgevoerd';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nieuw JAP Aanmaken', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doelstellingController,
              decoration: const InputDecoration(labelText: 'Doelstelling - maatregel *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _domein,
              items: ['Arbeidsveiligheid', 'Welzijnbeleid']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _domein = v!),
              decoration: const InputDecoration(labelText: 'Domein *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _risico,
                    items: ['Algemeen']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _risico = v!),
                    decoration: const InputDecoration(labelText: 'Risicoveld *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Uitvoerder *'),
                    onChanged: (v) => _uitvoerder = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _prioriteit,
                    items: ['Hoge prioriteit', 'Middelhoge prioriteit', 'Lage prioriteit']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _prioriteit = v!),
                    decoration: const InputDecoration(labelText: 'Prioriteit *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _realisatie,
                    items: ['Uitgevoerd', 'In uitvoering', 'Nog niet uitgevoerd']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _realisatie = v!),
                    decoration: const InputDecoration(labelText: 'Realisatie *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _opmerkingController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Opmerking'),
            ),
            const SizedBox(height: 12),
            _DateField(
              label: 'Jaar (startdatum) *',
              date: _startDate,
              onPick: (date) => setState(() => _startDate = date),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final doelstelling = _doelstellingController.text.trim();
                    if (_startDate == null || doelstelling.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vul alle verplichte velden in.')),
                      );
                      return;
                    }
                    try {
                      await JapApiService.createJapEntry(
                        token: widget.token,
                        payload: {
                          'doelstellingMaatregel': doelstelling,
                          'domein': _domein,
                          'jaar': _startDate!.year,
                          'prioriteit': _prioriteitToApiString(_prioriteit),
                          'realisatie': _realisatieToApiString(_realisatie),
                          'uitvoerder': _uitvoerder,
                          'opmerking': _opmerkingController.text.trim(),
                        },
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        widget.onSaved();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fout: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('Opslaan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateGppForm extends StatefulWidget {
  final String token;
  final VoidCallback onSaved;

  const _CreateGppForm({required this.token, required this.onSaved});

  @override
  State<_CreateGppForm> createState() => _CreateGppFormState();
}

class _CreateGppFormState extends State<_CreateGppForm> {
  final _doelstellingController = TextEditingController();
  final _opmerkingController = TextEditingController();

  String _domein = 'Arbeidsveiligheid';
  String _risico = 'Algemeen';
  String _uitvoerder = '';

  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _doelstellingController.dispose();
    _opmerkingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Nieuw GPP Aanmaken', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _doelstellingController,
              decoration: const InputDecoration(labelText: 'Doelstelling - maatregel *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _domein,
              items: ['Arbeidsveiligheid', 'Welzijnbeleid']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _domein = v!),
              decoration: const InputDecoration(labelText: 'Domein *'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _risico,
                    items: ['Algemeen']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _risico = v!),
                    decoration: const InputDecoration(labelText: 'Risicoveld *'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Uitvoerder *'),
                    onChanged: (v) => _uitvoerder = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _opmerkingController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Opmerking'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Startjaar *',
                    date: _startDate,
                    onPick: (date) => setState(() => _startDate = date),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'Eindjaar *',
                    date: _endDate,
                    onPick: (date) => setState(() => _endDate = date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuleren'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final doelstelling = _doelstellingController.text.trim();
                    if (_startDate == null || _endDate == null || doelstelling.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vul alle verplichte velden in.')),
                      );
                      return;
                    }
                    try {
                      await JapApiService.createGppEntry(
                        token: widget.token,
                        payload: {
                          'doelstellingMaatregel': doelstelling,
                          'domein': _domein,
                          'startJaar': _startDate!.year,
                          'eindJaar': _endDate!.year,
                          'uitvoerder': _uitvoerder,
                          'opmerking': _opmerkingController.text.trim(),
                        },
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        widget.onSaved();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fout: ${e.toString()}')),
                        );
                      }
                    }
                  },
                  child: const Text('Opslaan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Function(DateTime) onPick;

  const _DateField({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          date != null ? "${date!.day}/${date!.month}/${date!.year}" : 'Selecteer datum',
        ),
      ),
    );
  }
}