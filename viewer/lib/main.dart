import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_json_viewer/flutter_json_viewer.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const String url =
      'https://github.com/christopherfujino/fmr-reports/blob/main/3.10.0-1.1.pre/dependencies.json';
  @override
  void initState() {
    super.initState();
    _future = _parseBlob(http.get(Uri.parse(url)));
  }

  static Future<Map<String, Object?>> _parseBlob(
      Future<http.Response> futureResponse) async {
    final response = await futureResponse;
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  late final Future<Map<String, Object?>> _future;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FutureBuilder(
              future: _future,
              builder: (BuildContext ctx,
                  AsyncSnapshot<Map<String, Object?>> snapshot) {
                if (snapshot.hasData) {
                  return JsonViewer(snapshot.data!);
                } else if (snapshot.hasError) {
                  return const TextSpan(children: <TextSpan>[
                    TextSpan('Failed to load '),
                    SelectableText(url),
                    TextSpan('\n\n${snapshot.error}'),
                  ]);
                  return Text('Failed to load $url\n${snapshot.error.toString()}');
                } else {
                  return const Text('loading...');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
