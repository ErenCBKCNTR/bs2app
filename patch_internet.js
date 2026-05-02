const fs = require('fs');

const filesToPatch = [
  'lib/features/chat/presentation/screens/blog_screen.dart',
  'lib/features/chat/presentation/screens/chat_list_screen.dart',
  'lib/features/chat/presentation/screens/chat_detail_screen.dart'
];

for (const file of filesToPatch) {
  let content = fs.readFileSync(file, 'utf8');
  content = content.replace(
    /final result = await InternetAddress\.lookup\('api\.cabukcan\.com'\)\.timeout\(const Duration\(seconds: 3\)\);\s*if\s*\(result\.isEmpty\s*\|\|\s*result\[0\]\.rawAddress\.isEmpty\)\s*\{\s*hasInternet = false;\s*\}/g,
    `if (kIsWeb) {
          // Web'de dart:io desteklenmez, varsayýlan olarak true býrak.
        } else {
          final result = await InternetAddress.lookup('api.cabukcan.com').timeout(const Duration(seconds: 3));
          if (result.isEmpty || result[0].rawAddress.isEmpty) {
            hasInternet = false;
          }
        }`
  );
  
  if (!content.includes("import 'package:flutter/foundation.dart';")) {
      content = "import 'package:flutter/foundation.dart';\n" + content;
  }

  fs.writeFileSync(file, content);
}
console.log("Patched internet checks");
