import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../repositories/garage_repository.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  Stream<List<Map<String, dynamic>>>? _requests;
  Stream<List<Map<String, dynamic>>>? _notificationStream;

  CustomerWorkflowRepository? get _repository {
    final repository = context.read<GarageController>().repository;
    return repository is CustomerWorkflowRepository
        ? repository as CustomerWorkflowRepository
        : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() {
    final repository = _repository;
    if (repository == null) return;
    _requests = repository.watchCustomerRequests();
    _notificationStream = repository.watchNotifications();
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('cancelRequest')),
        content: Text(l10n.t('confirmCancelRequest')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.t('keepRequest')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.t('cancelRequest')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repository = _repository;
    if (repository == null) return;
    try {
      final cancelled = await repository.cancelServiceRequest(
        request['id'] as String,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.t(cancelled ? 'requestCancelled' : 'requestNoLongerPending'),
          ),
        ),
      );
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l10n = AppLocalizations.of(context);
    final repository = _repository;
    if (!auth.isSignedIn || repository == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('activity'))),
        body: Center(child: Text(l10n.t('accountRequired'))),
      );
    }
    return DefaultTabController(
      initialIndex: auth.isGarageOwner ? 1 : 0,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('activity')),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.t('myRequests')),
              Tab(text: l10n.t('notifications')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActivityList(
              stream: _requests,
              emptyLabel: l10n.t('noRequests'),
              onRefresh: () async => setState(_reload),
              itemBuilder: (context, row) {
                final garageName =
                    row['garages']?['name'] as String? ??
                    context
                        .read<GarageController>()
                        .findById(row['garage_id'] as String)
                        ?.name ??
                    '';
                return ListTile(
                  leading: const Icon(Icons.car_repair),
                  title: Text(
                    '${row['vehicle'] ?? ''} · ${l10n.t('requestStatus_${row['status']}')}',
                  ),
                  subtitle: Text(
                    '$garageName\n${row['issue_description'] ?? ''}${row['response_eta_minutes'] == null ? '' : '\n${l10n.t('etaMinutes')}: ${row['response_eta_minutes']}'}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: row['status'] == 'pending'
                      ? IconButton(
                          tooltip: l10n.t('cancelRequest'),
                          icon: const Icon(Icons.cancel_outlined),
                          onPressed: () => _cancelRequest(row),
                        )
                      : null,
                );
              },
            ),
            _NotificationList(
              stream: _notificationStream,
              emptyLabel: l10n.t('noNotifications'),
              onMarkRead: repository.markNotificationRead,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? stream;
  final String emptyLabel;
  final Future<void> Function(String id) onMarkRead;

  const _NotificationList({
    required this.stream,
    required this.emptyLabel,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) return Center(child: Text(emptyLabel));
          return ListView.separated(
            itemCount: snapshot.data!.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final row = snapshot.data![index];
              final unread = row['read_at'] == null;
              return ListTile(
                leading: Icon(
                  unread
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none,
                ),
                title: Text(row['title'] as String? ?? ''),
                subtitle: Text(row['body'] as String? ?? ''),
                trailing: unread
                    ? IconButton(
                        tooltip: AppLocalizations.of(context).t('markRead'),
                        icon: const Icon(Icons.done),
                        onPressed: () => onMarkRead(row['id'] as String),
                      )
                    : null,
              );
            },
          );
        },
      );
}

class _ActivityList extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? stream;
  final String emptyLabel;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;

  const _ActivityList({
    required this.stream,
    required this.emptyLabel,
    required this.onRefresh,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) return Center(child: Text(emptyLabel));
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              itemCount: snapshot.data!.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  itemBuilder(context, snapshot.data![index]),
            ),
          );
        },
      );
}
