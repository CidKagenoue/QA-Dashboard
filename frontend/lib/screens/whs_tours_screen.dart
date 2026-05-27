import 'package:flutter/material.dart';

import '../models/whs_tour.dart';
import '../services/whs_api_service.dart';
import '../widgets/design/design_system.dart';

class WhsToursScreen extends StatefulWidget {
  const WhsToursScreen({super.key, required this.token});

  final String token;

  @override
  State<WhsToursScreen> createState() => _WhsToursScreenState();
}

class _WhsToursScreenState extends State<WhsToursScreen> {
  bool isLoading = true;
  String? loadError;
  List<WhsTour> tours = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isLoading && tours.isEmpty && loadError == null) {
      _loadTours();
    }
  }

  Future<void> _loadTours() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final token = widget.token;
      final list = await WhsApiService.fetchTours(token: token);
      if (!mounted) return;
      setState(() {
        tours = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBackground,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadius2xl),
          border: Border.all(color: kBorder),
        ),
        child: RefreshIndicator(
          onRefresh: _loadTours,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(36, 32, 36, 36),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WhsHeader(
                        tourCount: tours.length,
                        isLoading: isLoading,
                        onRefresh: _loadTours,
                      ),
                      const SizedBox(height: 30),
                      _WhsContent(
                        isLoading: isLoading,
                        loadError: loadError,
                        tours: tours,
                        onRetry: _loadTours,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WhsHeader extends StatelessWidget {
  const _WhsHeader({
    required this.tourCount,
    required this.isLoading,
    required this.onRefresh,
  });

  final int tourCount;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppBreadcrumb(segments: ['Dashboard', 'WHS-Tours']),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'WHS-Tours',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
            OutlinedButton.icon(
              onPressed: isLoading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Vernieuwen'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tourCount == 1
              ? 'Bekijk de meest recente WHS-tour en bijhorende locatiegegevens.'
              : 'Bekijk recente WHS-tours en bijhorende locatiegegevens.',
          style: const TextStyle(
            fontSize: 15,
            color: kTextSecondary,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _WhsContent extends StatelessWidget {
  const _WhsContent({
    required this.isLoading,
    required this.loadError,
    required this.tours,
    required this.onRetry,
  });

  final bool isLoading;
  final String? loadError;
  final List<WhsTour> tours;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        children: [
          AppListRowSkeleton(),
          SizedBox(height: 12),
          AppListRowSkeleton(),
          SizedBox(height: 12),
          AppListRowSkeleton(),
        ],
      );
    }

    if (loadError != null) {
      return AppEmptyState.emphasis(
        icon: Icons.error_outline_rounded,
        title: 'WHS tours konden niet geladen worden',
        message: loadError!,
        actionLabel: 'Opnieuw proberen',
        onAction: onRetry,
      );
    }

    if (tours.isEmpty) {
      return const AppEmptyState.emphasis(
        icon: Icons.tour_outlined,
        title: 'Nog geen WHS tours beschikbaar',
        message: 'Zodra er WHS-tours geregistreerd zijn, verschijnen ze hier.',
      );
    }

    return Column(
      children: List.generate(tours.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == tours.length - 1 ? 0 : 12),
          child: _WhsTourCard(tour: tours[index]),
        );
      }),
    );
  }
}

class _WhsTourCard extends StatefulWidget {
  const _WhsTourCard({required this.tour});

  final WhsTour tour;

  @override
  State<_WhsTourCard> createState() => _WhsTourCardState();
}

class _WhsTourCardState extends State<_WhsTourCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tour = widget.tour;
    final title = tour.vestigingAddress?.trim().isNotEmpty == true
        ? tour.vestigingAddress!.trim()
        : 'Onbekende locatie';
    final author = _authorLabel(tour);
    final date = _dateLabel(tour.datum);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
        child: Material(
          color: kSurface,
          borderRadius: BorderRadius.circular(kRadiusLg),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusLg),
            onTap: () {
              // Detailnavigatie kan hier later op aansluiten.
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kRadiusLg),
                border: Border.all(
                  color: _hovered ? kBrandGreenDark : kBorder,
                  width: _hovered ? 1.4 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kBrandGreenSubtle,
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.tour_outlined,
                      color: kBrandGreenDeep,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            if (author != null)
                              _TourMeta(
                                icon: Icons.person_outline_rounded,
                                label: author,
                              ),
                            if (date != null)
                              _TourMeta(
                                icon: Icons.calendar_today_outlined,
                                label: date,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _TourIdPill(id: tour.id),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: kTextMuted,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _authorLabel(WhsTour tour) {
    final parts = [
      tour.gebruikerVoornaam,
      tour.gebruikerAchternaam,
    ].where((part) => part != null && part.trim().isNotEmpty);
    final label = parts.map((part) => part!.trim()).join(' ');
    if (label.isNotEmpty) return label;

    final email = tour.gebruikerEmail;
    if (email != null && email.trim().isNotEmpty) return email.trim();
    return null;
  }

  String? _dateLabel(DateTime? date) {
    if (date == null) return null;

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _TourMeta extends StatelessWidget {
  const _TourMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: kTextMuted),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: kTextTertiary,
          ),
        ),
      ],
    );
  }
}

class _TourIdPill extends StatelessWidget {
  const _TourIdPill({required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceMuted,
        borderRadius: BorderRadius.circular(kRadiusPill),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '#${id.toString().padLeft(4, '0')}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: kTextTertiary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
