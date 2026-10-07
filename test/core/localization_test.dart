import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage_finder/core/localization/app_localizations.dart';

void main() {
  test('request cancellation and expiry states are translated in French', () {
    final localizations = AppLocalizations(const Locale('fr'));

    expect(localizations.t('requestStatus_cancelled'), 'Annulée par le client');
    expect(localizations.t('requestStatus_expired'), 'Expirée sans réponse');
    expect(localizations.t('cancelRequest'), 'Annuler la demande');
  });

  test('request cancellation and expiry states are translated in English', () {
    final localizations = AppLocalizations(const Locale('en'));

    expect(localizations.t('requestStatus_cancelled'), 'Cancelled by you');
    expect(
      localizations.t('requestStatus_expired'),
      'Expired without a response',
    );
    expect(localizations.t('cancelRequest'), 'Cancel request');
  });
}
