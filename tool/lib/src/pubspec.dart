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
  String get version => root['version'];
}
