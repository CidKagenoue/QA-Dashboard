// lib/screens/jap_gpp_screen.dart

import 'package:flutter/material.dart';
import '../models/jap_entry.dart';

// ---------------------------------------------------------------------------
// Mock data – remove once the real API is wired up
// ---------------------------------------------------------------------------
final _mockEntries = [
  JapEntry(
    id: 1,
    jaar: 2024,
    doelstellingMaatregel: 'Opmaken van een procedure werken met derden',
    domein: 'Arbeidsveiligheid',
    prioriteit: JapPriority.laag,
    realisatie: JapRealisatie.inUitvoering,
  ),
  JapEntry(
    id: 2,
    jaar: 2025,
    doelstellingMaatregel:
        'Schoonmaakplan opstellen Horeca inclusief legionella…',
    domein: 'Arbeidsveiligheid',
    prioriteit: JapPriority.middel,
    realisatie: JapRealisatie.uitgevoerd,
  ),
  JapEntry(
    id: 3,
    jaar: 2025,
    doelstellingMaatregel: 'Opmaken intern noodplan',
    domein: 'Arbeidsveiligheid',
    prioriteit: JapPriority.laag,
    realisatie: JapRealisatie.negNietUitgevoerd,
  ),
  JapEntry(
    id: 4,
    jaar: 2026,
    doelstellingMaatregel: 'Nieuwe procedure AO wordt uitgewerkt',
    domein: 'Welzijnbeleid',
    prioriteit: JapPriority.hoog,
    realisatie: JapRealisatie.uitgevoerd,
  ),
  JapEntry(
    id: 5,
    jaar: 2026,
    doelstellingMaatregel:
        'Opmaken van een procedure voor een medewerkers die …',
    domein: 'Arbeidsveiligheid',
    prioriteit: JapPriority.laag,
    realisatie: JapRealisatie.uitgevoerd,
  ),
  JapEntry(
    id: 6,
    jaar: 2021,
    eindJaar: 2026,
    doelstellingMaatregel: 'Bij elke opmaak van een prijsofferte voor …',
    domein: 'Vul aan',
    prioriteit: JapPriority.laag,
    realisatie: JapRealisatie.uitgevoerd,
  ),
  JapEntry(
    id: 7,
    jaar: 2021,
    eindJaar: 2026,
    doelstellingMaatregel: 'Veiligheids- (instructie) films op de flatscreen',
    domein: 'Arbeidsveiligheid',
    prioriteit: JapPriority.hoog,
    realisatie: JapRealisatie.uitgevoerd,
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class JapGppScreen extends StatefulWidget {
  const JapGppScreen({super.key});
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

  String? _filterPriority; // 'hoog' | 'middel' | 'laag' | null
  int? _filterYear;

  // ── active tab (JAP | GPP) ────────────────────────────────────────────────
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── data loading ──────────────────────────────────────────────────────────
  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // TODO: uncomment once backend is ready and remove _mockEntries
      // final entries = await JapApiService.fetchJapEntries(token: widget.token);
      final entries = _mockEntries;

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
            e.doelstellingMaatregel.toLowerCase().contains(query) ||
            e.domein.toLowerCase().contains(query) ||
            e.jaarLabel.contains(query);
        if (!matchesQuery) return false;
      }
      if (_filterPriority != null) {
        final priorityMatch = switch (_filterPriority) {
          'hoog' => e.prioriteit == JapPriority.hoog,
          'middel' => e.prioriteit == JapPriority.middel,
          'laag' => e.prioriteit == JapPriority.laag,
          _ => true,
        };
        if (!priorityMatch) return false;
      }
      if (_filterYear != null && e.jaar != _filterYear) return false;
      return true;
    }).toList();

    setState(() => _filtered = result);
  }

  void _showFilterSheet() {
    final years = _allEntries.map((e) => e.jaar).toSet().toList()..sort();

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
                  // Header
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

                  // Priority filter
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

                  // Year filter
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

                  // Apply button
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
          Text(
            'Dashboard',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child:
                Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
          ),
          Text(
            'JAP & GPP',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Text(
        'JAP & GPP',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
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
                  onTap: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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

  Widget _buildToolbar() {
    return Row(
      children: [
        const Spacer(),

        // Search bar
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Zoeken',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF8CC63F),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Filter icon button
        IconButton(
          onPressed: _showFilterSheet,
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: 'Filteren',
          color: const Color(0xFF6B7A62),
        ),

        const SizedBox(width: 4),

        // New entry button
        ElevatedButton.icon(
          onPressed: () {
            // TODO: navigate to new JAP entry screen
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nieuw'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CC63F),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
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
              0: FixedColumnWidth(32),  // icon
              1: FixedColumnWidth(90),  // jaar
              2: FlexColumnWidth(3),    // doelstelling
              3: FlexColumnWidth(2),    // domein
              4: FlexColumnWidth(1.6),  // prioriteit
              5: FlexColumnWidth(1.6),  // realisatie
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
        border: Border(
          bottom: BorderSide(color: Color(0xFFE4E9DD)),
        ),
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
      padding: EdgeInsets.only(
        left: 8,
        right: isLast ? 16 : 8,
        top: 12,
        bottom: 12,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7A62),
        ),
      ),
    );
  }

  TableRow _buildDataRow(JapEntry entry) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0F2EC)),
        ),
      ),
      children: [
        // document icon
        Padding(
          padding: const EdgeInsets.only(left: 12, top: 14, bottom: 14),
          child: Icon(
            Icons.insert_drive_file_outlined,
            size: 18,
            color: Colors.grey[400],
          ),
        ),
        // jaar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            entry.jaarLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF243022),
            ),
          ),
        ),
        // doelstelling
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            entry.doelstellingMaatregel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2F382E)),
          ),
        ),
        // domein
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            entry.domein,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4D5548)),
          ),
        ),
        // prioriteit badge
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: _PriorityBadge(priority: entry.prioriteit),
        ),
        // realisatie
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: _RealisatieLabel(realisatie: entry.realisatie),
        ),
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

  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color:
                  selected ? const Color(0xFF8CC63F) : Colors.transparent,
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
                : (onTap == null
                    ? const Color(0xFFBBC3B4)
                    : const Color(0xFF6B7A62)),
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
      JapPriority.hoog => (
          'Hoge prioriteit',
          const Color(0xFFFFEDED),
          const Color(0xFFD32F2F),
        ),
      JapPriority.middel => (
          'Middelhoge prioriteit',
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
        ),
      JapPriority.laag => (
          'Lage prioriteit',
          const Color(0xFFF1F1F1),
          const Color(0xFF757575),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _RealisatieLabel extends StatelessWidget {
  final JapRealisatie realisatie;

  const _RealisatieLabel({required this.realisatie});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (realisatie) {
      JapRealisatie.inUitvoering => (
          'In Uitvoering',
          const Color(0xFF1565C0),
        ),
      JapRealisatie.uitgevoerd => (
          'Uitgevoerd',
          const Color(0xFF2E7D32),
        ),
      JapRealisatie.negNietUitgevoerd => (
          'Nog niet uitgevoerd',
          const Color(0xFFD32F2F),
        ),
      JapRealisatie.vulAan => (
          'Vul aan',
          const Color(0xFF6B7A62),
        ),
    };

    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF4D9) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF8CC63F)
                : const Color(0xFFD7DBD2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? const Color(0xFF4A7A1E)
                : const Color(0xFF4D5548),
          ),
        ),
      ),
    );
  }
}