const fs = require('fs');
let path = 'lib/features/servers/presentation/screens/server_settings_screen.dart';
let content = fs.readFileSync(path, 'utf8');

content = content.replace("class ServerSettingsScreen extends StatefulWidget", "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:blind_social/core/localization/localization_provider.dart';\n\nclass ServerSettingsScreen extends ConsumerStatefulWidget");
content = content.replace("State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();", "ConsumerState<ServerSettingsScreen> createState() => _ServerSettingsScreenState();");
content = content.replace("class _ServerSettingsScreenState extends State<ServerSettingsScreen>", "class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen>");

fs.writeFileSync(path, content);
console.log('Fixed server settings screen');
