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
      'http://raw.githubusercontent.com/christopherfujino/fmr-reports/main/3.10.0-1.1.pre/dependencies.json';
  //'https://www.google.com';
  @override
  void initState() {
    super.initState();
  }

  static Future<Map<String, Object?>> _fetchBlob() async {
    final response = await http.get(Uri.parse(url));
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  void _refetch() {
    setState(() {
      _future = _fetchBlob();
    });
  }

  Future<Map<String, Object?>> _future = _fetchBlob();

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
                  return Column(children: <Widget>[
                    SelectableText('Failed to load $url\n\n${snapshot.error}'),
                    TextButton.icon(
                      onPressed: _refetch,
                      label: const Text('Re-fetch'),
                      icon: const Icon(Icons.refresh),
                    ),
                  ]);
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
