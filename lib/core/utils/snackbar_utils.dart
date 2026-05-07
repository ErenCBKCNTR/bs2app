import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SnackbarUtils {
  /// Sabit bir SnackBar gösterir ve uzun basıldığında metni panoya kopyalar.
  static void showCopyableSnackbar(BuildContext context, String message, {bool isError = false, String? fullMessage}) {
    // ScaffoldMessenger.of(context).clearSnackBars(); // İsteğe bağlı, önceki hataları temizlemek için
    final String textToCopy = fullMessage ?? message;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: textToCopy));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Metin panoya kopyalandı!')),
              );
            }
          },
          child: SelectableText(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.grey[850],
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Kopyala',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: textToCopy));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Metin panoya kopyalandı!')),
              );
            }
          },
        ),
      ),
    );
  }
}
