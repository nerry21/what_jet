Map<String, dynamic>? asOmnichannelMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  return null;
}

List<Map<String, dynamic>> asOmnichannelMapList(Object? value) {
  if (value is! List) {
    return const <Map<String, dynamic>>[];
  }

  return value.map(asOmnichannelMap).whereType<Map<String, dynamic>>().toList();
}

Object? omnichannelValueAtPath(Map<String, dynamic> json, String path) {
  final segments = path.split('.');
  Object? current = json;

  for (final segment in segments) {
    if (current is Map) {
      current = current[segment];
      continue;
    }

    return null;
  }

  return current;
}

T? omnichannelFirstMapped<T>(
  Map<String, dynamic> json,
  List<String> paths,
  T? Function(Object? value) mapper,
) {
  for (final path in paths) {
    final mapped = mapper(omnichannelValueAtPath(json, path));
    if (mapped != null) {
      return mapped;
    }
  }

  return null;
}

T? omnichannelFirstMappedFromSources<T>(
  List<Map<String, dynamic>> sources,
  List<String> paths,
  T? Function(Object? value) mapper,
) {
  for (final source in sources) {
    final mapped = omnichannelFirstMapped(source, paths, mapper);
    if (mapped != null) {
      return mapped;
    }
  }

  return null;
}

Map<String, dynamic> omnichannelFirstMap(
  Map<String, dynamic> json,
  List<String> paths,
) {
  return omnichannelFirstMapped(json, paths, asOmnichannelMap) ??
      <String, dynamic>{};
}

Map<String, dynamic> omnichannelFirstMapFromSources(
  List<Map<String, dynamic>> sources,
  List<String> paths,
) {
  return omnichannelFirstMappedFromSources(sources, paths, asOmnichannelMap) ??
      <String, dynamic>{};
}

List<Map<String, dynamic>> omnichannelFirstMapList(
  Map<String, dynamic> json,
  List<String> paths,
) {
  return omnichannelFirstMapped(json, paths, (value) {
        final list = asOmnichannelMapList(value);
        return list.isEmpty ? null : list;
      }) ??
      const <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> omnichannelFirstMapListFromSources(
  List<Map<String, dynamic>> sources,
  List<String> paths,
) {
  return omnichannelFirstMappedFromSources(sources, paths, (value) {
        final list = asOmnichannelMapList(value);
        return list.isEmpty ? null : list;
      }) ??
      const <Map<String, dynamic>>[];
}

String? omnichannelString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? omnichannelInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

bool? omnichannelBool(Object? value) {
  if (value is bool) {
    return value;
  }

  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }

  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }

  return null;
}

DateTime? omnichannelDateTime(Object? value) {
  final text = omnichannelString(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text)?.toLocal();
}

List<String> omnichannelStringList(Object? value) {
  if (value is! List) {
    final direct = omnichannelString(value);
    return direct == null ? const <String>[] : <String>[direct];
  }

  return value.map(omnichannelString).whereType<String>().toList();
}

String humanizeOmnichannelKey(String key) {
  final normalized = key.replaceAll('-', ' ').replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }

  final words = normalized
      .split(' ')
      .where((segment) => segment.trim().isNotEmpty)
      .map((segment) {
        final lower = segment.trim().toLowerCase();
        if (lower.isEmpty) {
          return '';
        }
        if (lower.length == 1) {
          return lower.toUpperCase();
        }
        return '\${lower[0].toUpperCase()}\${lower.substring(1)}';
      })
      .where((segment) => segment.isNotEmpty)
      .toList();

  return words.join(' ');
}


String channelLabelForOmnichannel(String channel) {
  if (channel == 'mobile_live_chat') {
    return 'Live Chat';
  }

  if (channel == 'whatsapp') {
    return 'WhatsApp';
  }

  return humanizeOmnichannelKey(channel);
}

String joinOmnichannelText(
  List<String?> parts, {
  String separator = ' - ',
  String fallback = '',
}) {
  final filtered = parts
      .map(omnichannelString)
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toList();

  if (filtered.isEmpty) {
    return fallback;
  }

  return filtered.join(separator);
}
