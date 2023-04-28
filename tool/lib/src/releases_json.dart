import 'dart:convert';

import 'package:file/file.dart';

class ReleasesJson {
  ReleasesJson({required this.file}) {
    final root = jsonDecode(file.readAsStringSync());
    releases = (root['releases'] as List<Object?>).map<Release>((Object? obj) {
      return Release(obj! as Map<String, Object?>);
    });
  }

  final File file;
  late final Iterable<Release> releases;
}

class Release {
  Release(Map<String, Object?> blob)
      : hash = blob['hash']! as String,
        channel = blob['channel']! as String,
        version = (blob['version']! as String).replaceAll('v', ''),
        releaseDate = DateTime.parse(blob['release_date']! as String),
        archive = blob['archive']! as String,
        sha256 = blob['sha256']! as String;

  final String hash;
  final String channel;
  final String version;
  final DateTime releaseDate;
  final String archive;
  final String sha256;

  @override
  String toString() => '$channel $version $releaseDate';
}
