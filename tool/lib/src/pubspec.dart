import 'package:file/file.dart';
import 'package:yaml/yaml.dart';

class Pubspec {
  Pubspec(this.root);

  factory Pubspec.fromFile(File file) {
    final contents = file.readAsStringSync();
    final root = loadYaml(contents) as YamlMap;
    return Pubspec(root);
  }

  final YamlMap root;

  String get name => root['name'];
  String? get version => root['version'];

  Map<String, String> get dependencies {
    // TODO: what about dev_dependencies?
    final dependencies = root['dependencies'];
    final dependencyYamlMap = dependencies as YamlMap;
    // cast from YamlMap -> Map<dynamic, dynamic> -> Map<String, String>
    return Map<String, String>.fromEntries(
      dependencyYamlMap.entries
          .map<MapEntry<String, String>>((MapEntry<Object?, Object?> entry) {
        return MapEntry<String, String>(
            entry.key as String, entry.value as String);
      }),
    );
  }
}
