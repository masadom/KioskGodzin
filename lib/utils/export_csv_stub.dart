import 'package:flutter/material.dart';

void exportCsv(String csv, BuildContext context) {
  // Na platformach innych niż web tylko komunikat
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Eksport CSV dostępny w wersji web.')),
  );
}
