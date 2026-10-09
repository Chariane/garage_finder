typedef MapCoordinates = ({double latitude, double longitude});

class GoogleMapsLink {
  const GoogleMapsLink._();

  static MapCoordinates? parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        !_isGoogleMapsHost(uri.host.toLowerCase())) {
      return null;
    }

    final source = '${uri.path}?${uri.query}#${uri.fragment}';
    final candidates = <String>[
      for (final key in ['q', 'query', 'destination', 'daddr', 'll', 'center'])
        ?uri.queryParameters[key],
      source,
    ];
    for (final candidate in candidates) {
      final match = RegExp(
        r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
      ).firstMatch(candidate);
      if (match == null) continue;
      final coordinates = _validated(
        double.tryParse(match.group(1)!),
        double.tryParse(match.group(2)!),
      );
      if (coordinates != null) return coordinates;
    }

    final dataMatch = RegExp(
      r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
    ).firstMatch(source);
    if (dataMatch == null) return null;
    return _validated(
      double.tryParse(dataMatch.group(1)!),
      double.tryParse(dataMatch.group(2)!),
    );
  }

  static bool _isGoogleMapsHost(String host) =>
      host == 'maps.app.goo.gl' ||
      host == 'goo.gl' ||
      host == 'maps.google.com' ||
      host == 'google.com' ||
      host.endsWith('.google.com');

  static MapCoordinates? _validated(double? latitude, double? longitude) {
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return (latitude: latitude, longitude: longitude);
  }
}
