import 'package:flutter/material.dart';

class Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool enabled;
  const Keypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '⌫',
      '0',
      'OK',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        final label = buttons[index];
        return ElevatedButton(
          onPressed: !enabled
              ? null
              : () {
                  if (label == '⌫') {
                    onBackspace();
                  } else if (label == 'OK') {
                    onSubmit();
                  } else {
                    onDigit(label);
                  }
                },
          child: Text(label, style: const TextStyle(fontSize: 20)),
        );
      },
    );
  }
}
