import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/whs_tour.dart';
import '../services/auth_service.dart';
import '../services/whs_api_service.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('WHS-Tours'),
        backgroundColor: const Color(0xFF8CC63F),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTours,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Builder(builder: (context) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF8CC63F)));
            }

            if (loadError != null) {
              return ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fout bij laden WHS tours', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(loadError!),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadTours,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8CC63F)),
                            child: const Text('Opnieuw proberen'),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            if (tours.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 64),
                  Center(child: Text('Nog geen WHS tours beschikbaar.')),
                ],
              );
            }

            return ListView.separated(
              itemCount: tours.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = tours[index];
                final title = t.vestigingAddress ?? 'Onbekende locatie';
                final author = (t.gebruikerVoornaam ?? '') + (t.gebruikerAchternaam != null ? ' ${t.gebruikerAchternaam}' : '');
                final subtitle = t.datum != null ? '${t.datum!.day.toString().padLeft(2,'0')}/${t.datum!.month.toString().padLeft(2,'0')}/${t.datum!.year}' : '';

                return Card(
                  child: ListTile(
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2B3424))),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (author.trim().isNotEmpty) Text(author, style: const TextStyle(color: Color(0xFF6B7A62))),
                        if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Color(0xFF6B7A62))),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF8CC63F)),
                    onTap: () {
                      // Future: open detail view; for now no-op
                    },
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
