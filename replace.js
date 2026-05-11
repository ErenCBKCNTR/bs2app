const fs = require('fs');

function replaceFiles() {
  // Update Languages
  let langPath = 'lib/core/localization/languages/language.dart';
  let lang = fs.readFileSync(langPath, 'utf8');
  if(!lang.includes('editPost')) {
    lang = lang.replace('String get deleteComment;', 'String get deleteComment;\n  String get editPost;\n  String get deletePost;\n  String get unlikePost;\n  String get likePost;\n  String get openComments;\n  String get deleteVoiceNote;\n  String get playRecording;\n  String get deleteRoom;\n  String get kickUser;\n  String get banUser;\n  String get unbanUser;\n  String get removeFromFavs;\n  String get playRecordAnnounce;');
    fs.writeFileSync(langPath, lang);
  }

  let enPath = 'lib/core/localization/languages/en_us.dart';
  let en = fs.readFileSync(enPath, 'utf8');
  if(!en.includes('editPost')) {
    en = en.replace('String get deleteComment => "Delete Comment";', 'String get deleteComment => "Delete Comment";\n  @override\n  String get editPost => "Edit Post";\n  @override\n  String get deletePost => "Delete Post";\n  @override\n  String get unlikePost => "Unlike Post";\n  @override\n  String get likePost => "Like Post";\n  @override\n  String get openComments => "Open Comments";\n  @override\n  String get deleteVoiceNote => "Delete Voice Note";\n  @override\n  String get playRecording => "Play Recording";\n  @override\n  String get deleteRoom => "Delete Room";\n  @override\n  String get kickUser => "Kick User";\n  @override\n  String get banUser => "Ban User";\n  @override\n  String get unbanUser => "Unban User";\n  @override\n  String get removeFromFavs => "Remove from Favorites";\n  @override\n  String get playRecordAnnounce => "Playing recording";');
    fs.writeFileSync(enPath, en);
  }

  let trPath = 'lib/core/localization/languages/tr_tr.dart';
  let tr = fs.readFileSync(trPath, 'utf8');
  if(!tr.includes('editPost')) {
    tr = tr.replace('String get deleteComment => "Yorumu Sil";', 'String get deleteComment => "Yorumu Sil";\n  @override\n  String get editPost => "Gönderiyi Düzenle";\n  @override\n  String get deletePost => "Gönderiyi Sil";\n  @override\n  String get unlikePost => "Beğeniyi Kaldır";\n  @override\n  String get likePost => "Beğen";\n  @override\n  String get openComments => "Yorumları Aç";\n  @override\n  String get deleteVoiceNote => "Kaydı Sil";\n  @override\n  String get playRecording => "Kaydı Oynat";\n  @override\n  String get deleteRoom => "Odayı Sil";\n  @override\n  String get kickUser => "Sunucudan At";\n  @override\n  String get banUser => "Kullanıcıyı Yasakla";\n  @override\n  String get unbanUser => "Yasak listesinden çıkar";\n  @override\n  String get removeFromFavs => "Favorilerden Kaldır";\n  @override\n  String get playRecordAnnounce => "Kayıt oynatılıyor";');
    fs.writeFileSync(trPath, tr);
  }

  // Replace in files
  const filesToProcess = [
    {
      path: 'lib/features/chat/presentation/screens/favorite_messages_screen.dart',
      replacements: [
        ['class FavoriteMessagesScreen extends StatefulWidget', "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:blind_social/core/localization/localization_provider.dart';\n\nclass FavoriteMessagesScreen extends ConsumerStatefulWidget"],
        ['State<FavoriteMessagesScreen>', 'ConsumerState<FavoriteMessagesScreen>'],
        ["CustomSemanticsAction(label: 'Favorilerden Kaldır')", "CustomSemanticsAction(label: ref.read(localizationProvider).removeFromFavs)"],
        ["title: widget.chatId != null \n        ? '${widget.chatName} - Favoriler' \n        : 'Favori Mesajlar';", "final title = widget.chatId != null ? '${widget.chatName} - Favoriler' : ref.watch(localizationProvider).favoriteMessages;"]
      ]
    },
    {
      path: 'lib/features/chat/presentation/screens/blog_screen.dart',
      replacements: [
        ['class BlogScreen extends StatefulWidget', "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:blind_social/core/localization/localization_provider.dart';\n\nclass BlogScreen extends ConsumerStatefulWidget"],
        ['State<BlogScreen>', 'ConsumerState<BlogScreen>'],
        ["CustomSemanticsAction(label: 'Gönderiyi Düzenle')", "CustomSemanticsAction(label: ref.read(localizationProvider).editPost)"],
        ["CustomSemanticsAction(label: 'Gönderiyi Sil')", "CustomSemanticsAction(label: ref.read(localizationProvider).deletePost)"],
        ["CustomSemanticsAction(label: isLiked ? 'Beğeniyi Kaldır' : 'Beğen')", "CustomSemanticsAction(label: isLiked ? ref.read(localizationProvider).unlikePost : ref.read(localizationProvider).likePost)"],
        ["CustomSemanticsAction(label: 'Yorumları Aç')", "CustomSemanticsAction(label: ref.read(localizationProvider).openComments)"],
      ]
    },
    {
      path: 'lib/features/chat/presentation/screens/my_blog_posts_screen.dart',
      replacements: [
        ['class MyBlogPostsScreen extends StatefulWidget', "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:blind_social/core/localization/localization_provider.dart';\n\nclass MyBlogPostsScreen extends ConsumerStatefulWidget"],
        ['State<MyBlogPostsScreen>', 'ConsumerState<MyBlogPostsScreen>'],
        ["CustomSemanticsAction(label: 'Gönderiyi Düzenle')", "CustomSemanticsAction(label: ref.read(localizationProvider).editPost)"],
        ["CustomSemanticsAction(label: 'Gönderiyi Sil')", "CustomSemanticsAction(label: ref.read(localizationProvider).deletePost)"],
        ["CustomSemanticsAction(label: isLiked ? 'Beğeniyi Kaldır' : 'Beğen')", "CustomSemanticsAction(label: isLiked ? ref.read(localizationProvider).unlikePost : ref.read(localizationProvider).likePost)"],
        ["CustomSemanticsAction(label: 'Yorumları Aç')", "CustomSemanticsAction(label: ref.read(localizationProvider).openComments)"]
      ]
    },
    {
      path: 'lib/features/chat/presentation/screens/archived_messages_screen.dart',
      replacements: [
        ['class ArchivedMessagesScreen extends StatefulWidget', "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:blind_social/core/localization/localization_provider.dart';\n\nclass ArchivedMessagesScreen extends ConsumerStatefulWidget"],
        ['State<ArchivedMessagesScreen>', 'ConsumerState<ArchivedMessagesScreen>'],
        ["CustomSemanticsAction(label: 'Arşivden çıkar')", "CustomSemanticsAction(label: ref.read(localizationProvider).unarchiveChat)"],
        ["title: const Text('Arşivlenmiş Sohbetler')", "title: Text(ref.watch(localizationProvider).archivedChats)"]
      ]
    },
    {
      path: 'lib/features/task_board/presentation/widgets/task_voice_notes_widget.dart',
      replacements: [
        ["CustomSemanticsAction(label: 'Kaydı Sil')", "CustomSemanticsAction(label: ref.read(localizationProvider).deleteVoiceNote)"]
      ]
    },
    {
      path: 'lib/features/radio/presentation/screens/saved_recordings_screen.dart',
      replacements: [
        ["CustomSemanticsAction(label: 'Kaydı Oynat')", "CustomSemanticsAction(label: ref.read(localizationProvider).playRecording)"],
        ["CustomSemanticsAction(label: 'Kaydı Paylaş')", "CustomSemanticsAction(label: ref.read(localizationProvider).shareRecording)"],
        ["CustomSemanticsAction(label: 'Kaydı Sil')", "CustomSemanticsAction(label: ref.read(localizationProvider).deleteRecording)"]
      ]
    },
    {
      path: 'lib/features/servers/presentation/screens/server_settings_screen.dart',
      replacements: [
        ["CustomSemanticsAction(label: 'Odayı sil')", "CustomSemanticsAction(label: ref.read(localizationProvider).deleteRoom)"],
        ["CustomSemanticsAction(label: 'Sunucudan At')", "CustomSemanticsAction(label: ref.read(localizationProvider).kickUser)"],
        ["CustomSemanticsAction(label: 'Kullanıcıyı Yasakla')", "CustomSemanticsAction(label: ref.read(localizationProvider).banUser)"],
        ["CustomSemanticsAction(label: 'Yasak listesinden çıkar')", "CustomSemanticsAction(label: ref.read(localizationProvider).unbanUser)"]
      ]
    }
  ];

  for(let file of filesToProcess) {
    if(!fs.existsSync(file.path)) {
      console.error('File not found:', file.path);
      continue;
    }
    let content = fs.readFileSync(file.path, 'utf8');
    for(let r of file.replacements) {
      content = content.replace(r[0], r[1]);
    }
    fs.writeFileSync(file.path, content);
    console.log('Processed', file.path);
  }
}

replaceFiles();
