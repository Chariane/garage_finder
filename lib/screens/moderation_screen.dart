import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/garage_controller.dart';
import '../core/localization/app_localizations.dart';
import '../repositories/garage_repository.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  Future<List<Map<String, dynamic>>>? _reports;
  Future<List<Map<String, dynamic>>>? _garages;

  ModerationRepository? get _repository {
    final repository = context.read<GarageController>().repository;
    return repository is ModerationRepository
        ? repository as ModerationRepository
        : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final repository = _repository;
    if (repository == null) return;
    _reports = repository.getReports();
    _garages = repository.getGarageReviewQueue();
  }

  Future<void> _reviewGarage(
    ModerationRepository repository,
    Map<String, dynamic> garage,
    String status,
  ) async {
    var note = '';
    if (status == 'rejected') {
      final controller = TextEditingController();
      String? validationError;
      final answer = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(AppLocalizations.of(context).t('reviewReject')),
            content: TextField(
              controller: controller,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setDialogState(() => validationError = null),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).t('moderationNote'),
                errorText: validationError,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).t('cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (controller.text.trim().length < 10) {
                    setDialogState(() {
                      validationError = AppLocalizations.of(
                        context,
                      ).t('moderationNoteRequired');
                    });
                    return;
                  }
                  Navigator.pop(context, controller.text.trim());
                },
                child: Text(AppLocalizations.of(context).t('reviewReject')),
              ),
            ],
          ),
        ),
      );
      controller.dispose();
      if (answer == null || !mounted) return;
      if (answer.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).t('moderationNoteRequired'),
            ),
          ),
        );
        return;
      }
      note = answer;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repository.updateGarageReviewStatus(
        garage['id'] as String,
        status,
        note: note,
      );
      if (mounted) setState(_load);
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
    final repository = _repository;
    if (auth.user?.appMetadata['role'] != 'admin' || repository == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('moderation'))),
        body: Center(child: Text(l10n.t('moderationAccessDenied'))),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.t('moderation')),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.t('garageReviewQueue')),
              Tab(text: l10n.t('reports')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ModerationList(
              future: _garages,
              emptyLabel: l10n.t('noPendingGarages'),
              onRefresh: () async => setState(_load),
              itemBuilder: (context, garage) => ListTile(
                title: Text(garage['name'] as String? ?? ''),
                subtitle: Text(
                  '${garage['city'] ?? ''} · ${garage['address'] ?? ''}\n${l10n.t('reviewStatus_${garage['review_status']}')}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: l10n.t('moderateGarage'),
                  onSelected: (status) =>
                      _reviewGarage(repository, garage, status),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'approved',
                      child: Text(l10n.t('reviewApprove')),
                    ),
                    PopupMenuItem(
                      value: 'rejected',
                      child: Text(l10n.t('reviewReject')),
                    ),
                  ],
                ),
              ),
            ),
            _ModerationList(
              future: _reports,
              emptyLabel: l10n.t('noReports'),
              onRefresh: () async => setState(_load),
              itemBuilder: (context, report) {
                final garage =
                    report['garages'] as Map<String, dynamic>? ?? const {};
                return ListTile(
                  title: Text(
                    '${garage['name'] ?? ''} · ${l10n.t('report_${report['category']}')}',
                  ),
                  subtitle: Text(
                    '${garage['city'] ?? ''} · ${l10n.t('reportStatus_${report['status']}')}\n${report['description'] ?? ''}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: l10n.t('updateReport'),
                    onSelected: (status) async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await repository.updateReportStatus(
                          report['id'] as String,
                          status,
                        );
                        if (mounted) setState(_load);
                      } catch (error) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'reviewing',
                        child: Text(l10n.t('reportReviewing')),
                      ),
                      PopupMenuItem(
                        value: 'resolved',
                        child: Text(l10n.t('reportResolved')),
                      ),
                      PopupMenuItem(
                        value: 'dismissed',
                        child: Text(l10n.t('reportDismissed')),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>>? future;
  final String emptyLabel;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;

  const _ModerationList({
    required this.future,
    required this.emptyLabel,
    required this.onRefresh,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
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
