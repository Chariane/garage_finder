import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../repositories/garage_repository.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Future<List<Garage>>? _garages;
  OwnerGarageRepository? _repository;
  String? _loadedOwnerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    final repository = context.read<GarageController>().repository;
    if (repository is OwnerGarageRepository &&
        !identical(repository, _repository)) {
      final ownerRepository = repository as OwnerGarageRepository;
      _repository = ownerRepository;
    }
    if (auth.isSignedIn &&
        auth.isGarageOwner &&
        auth.user?.id != _loadedOwnerId &&
        _repository != null) {
      _loadedOwnerId = auth.user!.id;
      _garages = _repository!.getOwnedGarages();
    }
  }

  void _reload() {
    final repository = _repository;
    if (repository == null) return;
    setState(() {
      _loadedOwnerId = context.read<AuthController>().user?.id;
      _garages = repository.getOwnedGarages();
    });
  }

  Future<void> _delete(Garage garage) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('deleteGarage')),
        content: Text(garage.name),
        actions: [
          IconButton(
            tooltip: l10n.t('notifications'),
            onPressed: () => context.go('/activity'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.t('deleteGarage')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repository!.deleteGarage(garage.id);
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _updateRequest(
    Map<String, dynamic> request,
    String status,
  ) async {
    final repository = _repository;
    if (repository == null) return;
    final messenger = ScaffoldMessenger.of(context);
    int? eta;
    if (status == 'accepted') {
      final etaController = TextEditingController();
      final answer = await showDialog<({bool confirm, int? eta})>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).t('acceptRequest')),
          content: TextField(
            controller: etaController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context).t('etaMinutes'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, (confirm: false, eta: null)),
              child: Text(AppLocalizations.of(context).t('cancel')),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(etaController.text.trim());
                if (etaController.text.trim().isNotEmpty &&
                    (value == null || value < 0 || value > 1440)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).t('invalidEta'),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(context, (confirm: true, eta: value));
              },
              child: Text(AppLocalizations.of(context).t('acceptRequest')),
            ),
          ],
        ),
      );
      etaController.dispose();
      if (answer?.confirm != true) return;
      eta = answer?.eta;
    }
    try {
      await repository.updateRequestStatus(
        request['id'] as String,
        status,
        responseEtaMinutes: eta,
      );
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context);
    if (!auth.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('ownerDashboard'))),
        body: Center(child: Text(l10n.t('backendMissing'))),
      );
    }
    if (!auth.isSignedIn || !auth.isGarageOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('ownerDashboard'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.t('accountRequired'), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/account'),
                  child: Text(l10n.t('account')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final future = _garages;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('ownerDashboard')),
        actions: [
          IconButton(
            tooltip: l10n.t('signOut'),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/garage/new'),
        icon: const Icon(Icons.add_business_outlined),
        label: Text(l10n.t('addMyGarage')),
      ),
      body: future == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<Garage>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(child: Text(snapshot.error.toString())),
                      ],
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final garages = snapshot.data!;
                  if (garages.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(child: Text(l10n.t('noGaragesYet'))),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: garages.length,
                    itemBuilder: (context, index) {
                      final garage = garages[index];
                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(garage.name),
                              subtitle: Text(
                                [
                                  '${garage.city} · ${_statusLabel(garage, l10n)}',
                                  if (garage.reviewStatus == 'rejected' &&
                                      garage.moderationNote.isNotEmpty)
                                    '${l10n.t('moderationNoteFromTeam')}: ${garage.moderationNote}',
                                ].join('\n'),
                              ),
                              isThreeLine:
                                  garage.reviewStatus == 'rejected' &&
                                  garage.moderationNote.isNotEmpty,
                              leading: Icon(
                                garage.isVerified
                                    ? Icons.verified_outlined
                                    : Icons.pending_actions_outlined,
                              ),
                              onTap: () =>
                                  context.push('/garage/edit', extra: garage),
                              trailing: PopupMenuButton<String>(
                                tooltip: l10n.t('editGarage'),
                                onSelected: (action) => action == 'edit'
                                    ? context.push(
                                        '/garage/edit',
                                        extra: garage,
                                      )
                                    : _delete(garage),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text(l10n.t('editGarage')),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text(l10n.t('deleteGarage')),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: DropdownButtonFormField<String>(
                                initialValue: garage.availabilityStatus,
                                decoration: InputDecoration(
                                  labelText: l10n.t('availability'),
                                ),
                                items: [
                                  for (final status in [
                                    'available',
                                    'busy',
                                    'emergency_only',
                                    'unavailable',
                                  ])
                                    DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        l10n.t('availability_$status'),
                                      ),
                                    ),
                                ],
                                onChanged: (status) async {
                                  if (status == null) {
                                    return;
                                  }
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  try {
                                    await _repository!.updateAvailability(
                                      garage.id,
                                      status,
                                    );
                                    _reload();
                                  } catch (error) {
                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(error.toString()),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                            ExpansionTile(
                              title: Text(l10n.t('incomingRequests')),
                              children: [
                                FutureBuilder<List<Map<String, dynamic>>>(
                                  future: _repository!.getGarageRequests(
                                    garage.id,
                                  ),
                                  builder: (context, requests) {
                                    if (requests.hasError) {
                                      return ListTile(
                                        title: Text(requests.error.toString()),
                                      );
                                    }
                                    if (!requests.hasData) {
                                      return const LinearProgressIndicator();
                                    }
                                    if (requests.data!.isEmpty) {
                                      return ListTile(
                                        title: Text(l10n.t('noRequests')),
                                      );
                                    }
                                    return Column(
                                      children: [
                                        for (final request in requests.data!)
                                          ListTile(
                                            title: Text(
                                              '${request['vehicle']} · ${l10n.t('requestStatus_${request['status']}')}',
                                            ),
                                            subtitle: Text(
                                              '${request['customer_phone']}\n${request['issue_description']}${request['customer_latitude'] == null ? '' : '\n${request['customer_latitude']}, ${request['customer_longitude']}'}',
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            isThreeLine: true,
                                            trailing:
                                                request['status'] == 'pending'
                                                ? PopupMenuButton<String>(
                                                    tooltip: l10n.t(
                                                      'updateRequest',
                                                    ),
                                                    onSelected: (status) =>
                                                        _updateRequest(
                                                          request,
                                                          status,
                                                        ),
                                                    itemBuilder: (_) => [
                                                      PopupMenuItem(
                                                        value: 'accepted',
                                                        child: Text(
                                                          l10n.t(
                                                            'acceptRequest',
                                                          ),
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'declined',
                                                        child: Text(
                                                          l10n.t(
                                                            'declineRequest',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : request['status'] ==
                                                      'accepted'
                                                ? PopupMenuButton<String>(
                                                    tooltip: l10n.t(
                                                      'updateRequest',
                                                    ),
                                                    onSelected: (status) =>
                                                        _updateRequest(
                                                          request,
                                                          status,
                                                        ),
                                                    itemBuilder: (_) => [
                                                      PopupMenuItem(
                                                        value: 'en_route',
                                                        child: Text(
                                                          l10n.t('enRoute'),
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'completed',
                                                        child: Text(
                                                          l10n.t(
                                                            'completeRequest',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : null,
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }

  String _statusLabel(Garage garage, AppLocalizations l10n) =>
      switch (garage.reviewStatus) {
        'approved' => l10n.t('approved'),
        'rejected' => l10n.t('rejected'),
        _ => l10n.t('pendingReview'),
      };
}
