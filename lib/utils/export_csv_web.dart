// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/material.dart';

void exportCsv(String csv, BuildContext context) {
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..setAttribute('download', 'shifts_export.csv')
    ..click();
  html.Url.revokeObjectUrl(url);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Wyeksportowano CSV.')));
}
