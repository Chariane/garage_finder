import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../models/garage.dart';
import '../repositories/garage_repository.dart';
import '../utils/contact_links.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Future<List<Garage>>? _garages;
  OwnerGarageRepository? _repository;
  String? _loadedOwnerId;
  final Map<String, List<Map<String, dynamic>>> _requestsByGarage = {};
  final List<StreamSubscription<List<Map<String, dynamic>>>>
  _requestSubscriptions = [];
  Object? _requestError;
  String _requestFilter = 'all';

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
      _garages = _loadOwnedGarages();
    }
  }

  Future<List<Garage>> _loadOwnedGarages() async {
    for (final subscription in _requestSubscriptions) {
      await subscription.cancel();
    }
    _requestSubscriptions.clear();
    _requestsByGarage.clear();
    _requestError = null;
    final garages = await _repository!.getOwnedGarages();
    for (final garage in garages) {
      final subscription = _repository!
          .watchGarageRequests(garage.id)
          .listen(
            (requests) {
              if (!mounted) return;
              setState(() => _requestsByGarage[garage.id] = requests);
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() => _requestError = error);
            },
          );
      _requestSubscriptions.add(subscription);
    }
    return garages;
  }

  @override
  void dispose() {
    for (final subscription in _requestSubscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  void _reload() {
    final repository = _repository;
    if (repository == null) return;
    setState(() {
      _loadedOwnerId = context.read<AuthController>().user?.id;
      _garages = _loadOwnedGarages();
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
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  List<Map<String, dynamic>> _requestsFor(List<Garage> garages) {
    final requests = [
      for (final garage in garages) ...?_requestsByGarage[garage.id],
    ];
    requests.sort((a, b) {
      final priority = _requestPriority(
        a['status'] as String,
      ).compareTo(_requestPriority(b['status'] as String));
      if (priority != 0) return priority;
      final aCreated = DateTime.tryParse(a['created_at'] as String? ?? '');
      final bCreated = DateTime.tryParse(b['created_at'] as String? ?? '');
      return (bCreated ?? DateTime(0)).compareTo(aCreated ?? DateTime(0));
    });
    return requests
        .where((request) {
          final status = request['status'];
          return switch (_requestFilter) {
            'pending' => status == 'pending',
            'active' => status == 'accepted' || status == 'en_route',
            'closed' => {
              'completed',
              'declined',
              'cancelled',
              'expired',
            }.contains(status),
            _ => true,
          };
        })
        .toList(growable: false);
  }

  static int _requestPriority(String status) => switch (status) {
    'pending' => 0,
    'accepted' => 1,
    'en_route' => 2,
    _ => 3,
  };

  Future<void> _openExternal(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('linkUnavailable')),
        ),
      );
    }
  }

  void _callCustomer(String phone) =>
      _openExternal(Uri(scheme: 'tel', path: phone.trim()));

  void _messageCustomer(String phone) {
    final uri = whatsappUri(phone);
    if (uri != null) _openExternal(uri);
  }

  void _openCustomerLocation(Map<String, dynamic> request) {
    final latitude = request['customer_latitude'];
    final longitude = request['customer_longitude'];
    if (latitude is! num || longitude is! num) return;
    _openExternal(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      }),
    );
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
            tooltip: l10n.t('notifications'),
            onPressed: () => context.go('/activity'),
            icon: const Icon(Icons.notifications_outlined),
          ),
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
          : FutureBuilder<List<Garage>>(
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
                final allRequests = [
                  for (final requests in _requestsByGarage.values) ...requests,
                ];
                final requests = _requestsFor(garages);
                final pendingCount = allRequests
                    .where((request) => request['status'] == 'pending')
                    .length;
                final activeCount = allRequests
                    .where(
                      (request) =>
                          request['status'] == 'accepted' ||
                          request['status'] == 'en_route',
                    )
                    .length;
                final closedCount = allRequests
                    .where(
                      (request) =>
                          _requestPriority(request['status'] as String) == 3,
                    )
                    .length;
                final showSetupGuide =
                    garages.isEmpty ||
                    garages.every((garage) => !garage.isVerified);
                final requestCount = requests.isEmpty ? 1 : requests.length;
                final setupOffset = showSetupGuide ? 1 : 0;
                final summaryIndex = setupOffset;
                final inboxIndex = summaryIndex + 1;
                final requestsStart = inboxIndex + 1;
                final garagesHeadingIndex = requestsStart + requestCount;
                final garagesStart = garagesHeadingIndex + 1;
                final bottomIndex = garagesStart + garages.length;
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _garages;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
                    itemCount: bottomIndex + 1,
                    itemBuilder: (context, index) {
                      if (showSetupGuide && index == 0) {
                        return _OwnerSetupGuide(
                          metadata: auth.user?.userMetadata ?? const {},
                          garages: garages,
                        );
                      }
                      if (index == summaryIndex) {
                        return _OwnerSummary(
                          pending: pendingCount,
                          active: activeCount,
                          closed: closedCount,
                        );
                      }
                      if (index == inboxIndex) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_requestError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  l10n.t('requestLoadFailed'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            _OwnerInboxHeader(
                              filter: _requestFilter,
                              allCount: allRequests.length,
                              pendingCount: pendingCount,
                              activeCount: activeCount,
                              closedCount: closedCount,
                              onFilterChanged: (value) =>
                                  setState(() => _requestFilter = value),
                            ),
                          ],
                        );
                      }
                      if (index >= requestsStart &&
                          index < garagesHeadingIndex) {
                        if (requests.isEmpty) {
                          final streamsReady = garages.every(
                            (garage) =>
                                _requestsByGarage.containsKey(garage.id),
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: _requestError != null
                                  ? Text(l10n.t('requestLoadFailed'))
                                  : !streamsReady
                                  ? const CircularProgressIndicator()
                                  : Text(
                                      allRequests.isEmpty
                                          ? l10n.t('noRequests')
                                          : l10n.t('noRequestsForFilter'),
                                    ),
                            ),
                          );
                        }
                        return _OwnerRequestCard(
                          request: requests[index - requestsStart],
                          onUpdate: (status) => _updateRequest(
                            requests[index - requestsStart],
                            status,
                          ),
                          onCall: _callCustomer,
                          onMessage: _messageCustomer,
                          onOpenLocation: _openCustomerLocation,
                        );
                      }
                      if (index == garagesHeadingIndex) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                          child: Text(
                            l10n.t('myGarages'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        );
                      }
                      if (index < bottomIndex) {
                        final garage = garages[index - garagesStart];
                        return _OwnerGarageCard(
                          garage: garage,
                          statusLabel: _statusLabel(garage, l10n),
                          onEdit: () =>
                              context.push('/garage/edit', extra: garage),
                          onDelete: () => _delete(garage),
                          onAvailabilityChanged: (status) async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await _repository!.updateAvailability(
                                garage.id,
                                status,
                              );
                              _reload();
                            } catch (error) {
                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          },
                        );
                      }
                      return const SizedBox(height: 8);
                    },
                  ),
                );
              },
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

class _OwnerSummary extends StatelessWidget {
  final int pending;
  final int active;
  final int closed;

  const _OwnerSummary({
    required this.pending,
    required this.active,
    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metrics = [
      (Icons.mark_email_unread_outlined, l10n.t('requestsToHandle'), pending),
      (Icons.handyman_outlined, l10n.t('requestsInProgress'), active),
      (Icons.task_alt_outlined, l10n.t('requestsClosed'), closed),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            for (final (icon, label, value) in metrics)
              Expanded(
                child: Column(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 6),
                    Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(label, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OwnerInboxHeader extends StatelessWidget {
  final String filter;
  final int allCount;
  final int pendingCount;
  final int activeCount;
  final int closedCount;
  final ValueChanged<String> onFilterChanged;

  const _OwnerInboxHeader({
    required this.filter,
    required this.allCount,
    required this.pendingCount,
    required this.activeCount,
    required this.closedCount,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      ('all', l10n.t('requestFilterAll'), allCount),
      ('pending', l10n.t('requestFilterPending'), pendingCount),
      ('active', l10n.t('requestFilterActive'), activeCount),
      ('closed', l10n.t('requestFilterClosed'), closedCount),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('ownerInbox'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (value, label, count) in options)
                ChoiceChip(
                  label: Text('$label · $count'),
                  selected: filter == value,
                  onSelected: (_) => onFilterChanged(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final ValueChanged<String> onUpdate;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onMessage;
  final ValueChanged<Map<String, dynamic>> onOpenLocation;

  const _OwnerRequestCard({
    required this.request,
    required this.onUpdate,
    required this.onCall,
    required this.onMessage,
    required this.onOpenLocation,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final phone = request['customer_phone'] as String? ?? '';
    final name = (request['customer_name'] as String?)?.trim();
    final status = request['status'] as String? ?? 'pending';
    final latitude = request['customer_latitude'];
    final longitude = request['customer_longitude'];
    final receivedAt = DateTime.tryParse(
      request['created_at'] as String? ?? '',
    )?.toLocal();
    final receivedText = receivedAt == null
        ? ''
        : '${receivedAt.day.toString().padLeft(2, '0')}/${receivedAt.month.toString().padLeft(2, '0')}/${receivedAt.year} · ${receivedAt.hour.toString().padLeft(2, '0')}:${receivedAt.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    (name?.isNotEmpty == true
                            ? name![0]
                            : l10n.t('clientName')[0])
                        .toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name?.isNotEmpty == true ? name! : l10n.t('clientName'),
                        style: theme.textTheme.titleMedium,
                      ),
                      SelectableText(phone),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.t('callCustomer'),
                  onPressed: phone.isEmpty ? null : () => onCall(phone),
                  icon: const Icon(Icons.call_outlined),
                ),
                IconButton(
                  tooltip: l10n.t('messageCustomer'),
                  onPressed: phone.isEmpty ? null : () => onMessage(phone),
                  icon: const Icon(Icons.chat_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(Icons.storefront_outlined, size: 18),
                  label: Text(
                    '${l10n.t('garageLabel')}: ${request['garage_name'] as String? ?? ''}',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.circle, size: 10),
                  label: Text(l10n.t('requestStatus_$status')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              request['vehicle'] as String? ?? '',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(request['issue_description'] as String? ?? ''),
            if (latitude is num && longitude is num)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onOpenLocation(request),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(l10n.t('openCustomerLocation')),
                ),
              ),
            if (receivedText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.t('requestReceivedAt')} · $receivedText',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            _requestActions(status, l10n),
          ],
        ),
      ),
    );
  }

  Widget _requestActions(String status, AppLocalizations l10n) {
    if (status == 'pending') {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          FilledButton.icon(
            onPressed: () => onUpdate('accepted'),
            icon: const Icon(Icons.check),
            label: Text(l10n.t('acceptRequest')),
          ),
          OutlinedButton.icon(
            onPressed: () => onUpdate('declined'),
            icon: const Icon(Icons.close),
            label: Text(l10n.t('declineRequest')),
          ),
        ],
      );
    }
    if (status == 'accepted') {
      return FilledButton.icon(
        onPressed: () => onUpdate('en_route'),
        icon: const Icon(Icons.directions_car_outlined),
        label: Text(l10n.t('enRoute')),
      );
    }
    if (status == 'en_route') {
      return FilledButton.icon(
        onPressed: () => onUpdate('completed'),
        icon: const Icon(Icons.task_alt),
        label: Text(l10n.t('completeRequest')),
      );
    }
    return const SizedBox.shrink();
  }
}

class _OwnerGarageCard extends StatelessWidget {
  final Garage garage;
  final String statusLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onAvailabilityChanged;

  const _OwnerGarageCard({
    required this.garage,
    required this.statusLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(garage.name),
            subtitle: Text(
              [
                '${garage.city} · $statusLabel',
                if (garage.phoneVerifiedAt != null) l10n.t('phoneVerified'),
                if (garage.onSiteVerifiedAt != null)
                  l10n.t('onSitePresenceVerified'),
                l10n.t(switch (garage.automatedReviewStatus) {
                  'passed' => 'autoChecksPassedShort',
                  'needs_review' => 'autoNeedsReviewShort',
                  _ => 'autoNotCheckedShort',
                }),
                if (garage.automatedReviewStatus == 'passed' &&
                    garage.reviewStatus == 'pending')
                  l10n.t('automatedReviewPassed'),
                for (final reason in garage.automatedReviewReasons)
                  l10n.t(switch (reason) {
                    'phone_used_by_another_owner' => 'phoneUsedByAnotherOwner',
                    'possible_duplicate_nearby' => 'possibleDuplicateNearby',
                    'garage_photo_missing' => 'garagePhotoMissing',
                    'on_site_presence_missing' => 'onSitePresenceMissing',
                    _ => 'autoNeedsReviewShort',
                  }),
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
            onTap: onEdit,
            trailing: PopupMenuButton<String>(
              tooltip: l10n.t('editGarage'),
              onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.t('editGarage'))),
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
              decoration: InputDecoration(labelText: l10n.t('availability')),
              items: [
                for (final status in [
                  'available',
                  'busy',
                  'emergency_only',
                  'unavailable',
                ])
                  DropdownMenuItem(
                    value: status,
                    child: Text(l10n.t('availability_$status')),
                  ),
              ],
              onChanged: (status) {
                if (status != null) onAvailabilityChanged(status);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerSetupGuide extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final List<Garage> garages;

  const _OwnerSetupGuide({required this.metadata, required this.garages});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileComplete =
        _hasValue(metadata['display_name']) &&
        _hasValue(metadata['phone']) &&
        _hasValue(metadata['garage_address']);
    final locationComplete =
        (metadata['garage_latitude'] is num &&
            metadata['garage_longitude'] is num) ||
        garages.any(
          (garage) => garage.latitude != null && garage.longitude != null,
        );
    final hasListing = garages.isNotEmpty;
    final approved = garages.any((garage) => garage.isVerified);
    final completed = [
      profileComplete,
      locationComplete,
      hasListing,
    ].where((step) => step).length;
    final steps = [
      (l10n.t('ownerProfileStep'), profileComplete),
      (l10n.t('ownerLocationStep'), locationComplete),
      (l10n.t('ownerListingStep'), hasListing),
      (approved ? l10n.t('approved') : l10n.t('ownerReviewStep'), approved),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.t('ownerSetupTitle'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('ownerSetupProgress').replaceAll('{done}', '$completed'),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: completed / 3),
            const SizedBox(height: 8),
            for (var i = 0; i < steps.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  steps[i].$2
                      ? Icons.check_circle_outline
                      : i == 3 && hasListing
                      ? Icons.hourglass_top
                      : Icons.radio_button_unchecked,
                ),
                title: Text(steps[i].$1),
                subtitle: i == 3 && hasListing && !approved
                    ? Text(l10n.t('ownerReviewInProgress'))
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  static bool _hasValue(Object? value) =>
      value is String && value.trim().isNotEmpty;
}
