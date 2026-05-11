import 'language.dart';

class LanguageTr extends BaseLanguage {
  @override
  String get appName => "Blind Social";
  @override
  String get ok => "Tamam";
  @override
  String get cancel => "İptal";
  @override
  String get save => "Kaydet";
  @override
  String get error => "Hata";
  @override
  String get loading => "Yükleniyor...";
  @override
  String get noData => "Veri bulunamadı";
  @override
  String get tryAgain => "Tekrar Deneyin";
  @override
  String get unknown => "Bilinmiyor";
  @override
  String get notSpecified => "Belirtilmemiş";

  // Login/Auth
  @override
  String get login => "Giriş Yap";
  @override
  String get logout => "Çıkış Yap";
  @override
  String get email => "E-posta";
  @override
  String get password => "Şifre";
  @override
  String get username => "Kullanıcı Adı";
  @override
  String get fullName => "Ad Soyad";
  @override
  String get forgotPassword => "Şifremi Unuttum";
  @override
  String get signUp => "Kayıt Ol";
  @override
  String get welcomeBack => "Tekrar Hoş Geldiniz";
  @override
  String get signOutAccount => "Hesaptan Çıkış Yap";

  // Profile
  @override
  String get profile => "Profil";
  @override
  String get editProfile => "Profili Düzenle";
  @override
  String get saveChanges => "Değişiklikleri Kaydet";
  @override
  String get deleteAccount => "Hesabımı Sil";
  @override
  String get deleteAccountConfirm => "Hesabınızı silmek istediğinize emin misiniz?";
  @override
  String get deleteAccountWarning => "Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinir.";
  @override
  String get updatingProfile => "Profil güncelleniyor...";
  @override
  String get invalidName => "Geçerli bir ad giriniz.";
  @override
  String get invalidUsername => "Geçerli bir kullanıcı adı giriniz.";
  @override
  String get settings => "Ayarlar";
  @override
  String get bio => "Hakkımda";
  @override
  String get dob => "Doğum Tarihi";
  @override
  String get joinedAt => "Katılım";
  @override
  String get myProfile => "Profilim";
  @override
  String get userProfile => "Kullanıcı Profili";
  @override
  String get personalInfo => "Kişisel Bilgiler";
  @override
  String get profilePhoto => "Profil fotoğrafınız";
  @override
  String get noBio => "Henüz bir biyografi eklenmemiş.";
  @override
  String get profileUpdateSuccess => "Profil başarıyla güncellendi.";
  @override
  String get bioHint => "Kendinizden bahsedin...";
  @override
  String get fullNameHint => "Adınızı ve soyadınızı girin";
  @override
  String get contactSupportForChange => "Not: Kullanıcı adınızı ve e-posta adresinizi değiştirmek için lütfen destek ekibiyle iletişime geçin.";

  // Settings
  @override
  String get appSettings => "Uygulama Ayarları";
  @override
  String get accessibility => "Erişilebilirlik";
  @override
  String get theme => "Tema";
  @override
  String get language => "Dil";
  @override
  String get fontSize => "Yazı Tipi Boyutu";
  @override
  String get notifications => "Bildirimler";
  @override
  String get privacy => "Gizlilik";
  @override
  String get changelog => "Sürüm Notları";
  @override
  String get feedback => "Geri Bildirim";
  @override
  String get systemTheme => "Sistem Teması";
  @override
  String get lightTheme => "Açık Tema";
  @override
  String get darkTheme => "Koyu Tema";
  @override
  String get themeDesc => "Cihaz ayarlarına göre değişir";
  @override
  String get voiceRoomNotif => "Sesli Oda Bildirimleri";
  @override
  String get voiceRoomNotifDesc => "Odadaki giriş çıkış yapan kullanıcıları sesli bildir";
  @override
  String get small => "Küçük";
  @override
  String get normal => "Normal";
  @override
  String get large => "Büyük";
  @override
  String get extraLarge => "Çok Büyük";
  @override
  String get fontSizeDesc => "Uygulama genelindeki metinlerin boyutunu ayarlayın";
  @override
  String get fontSizeExample => "Örnek Metin: Bu ayar uygulama genelindeki tüm yazıların boyutunu etkiler. Okumanızı kolaylaştırmak için size en uygun boyutu seçebilirsiniz.";

  // Chat
  @override
  String get chats => "Sohbetler";
  @override
  String get messagePlaceholder => "Mesaj yazın...";
  @override
  String get send => "Gönder";
  @override
  String get voiceMessage => "Sesli Mesaj";
  @override
  String get participants => "Katılımcılar";

  // Task Board
  @override
  String get taskBoard => "Görev Panosu";
  @override
  String get myBoards => "Panolarım";
  @override
  String get myTasks => "Görevlerim";
  @override
  String get addBoard => "Pano Ekle";
  @override
  String get addList => "Liste Ekle";
  @override
  String get addCard => "Kart Ekle";
  @override
  String get createBoard => "Pano Oluştur";
  @override
  String get boardName => "Pano Adı";
  @override
  String get boardStats => "Pano İstatistikleri";
  @override
  String get members => "Üyeler";
  @override
  String get checklist => "Kontrol Listesi";
  @override
  String get tags => "Etiketler";
  @override
  String get completed => "Tamamlandı";
  @override
  String get pending => "Bekliyor";
  @override
  String get totalTasksInCount => "Toplam {total} görev içerisinde, {completed} adet tamamlanan";
  @override
  String get taskDetail => "Görev Detayı";
  @override
  String get boardMembers => "Pano Üyeleri";
  @override
  String get overview => "Genel Bakış";
  @override
  String get description => "Açıklama";
  @override
  String get boardFilterAll => "Tüm panolar listeleniyor";
  @override
  String get boardFilterMy => "Sadece kendi panolarınız listeleniyor";
  @override
  String get boardFilterShared => "Sadece sizinle paylaşılan panolar listeleniyor";
  @override
  String get favAdded => "Pano favorilere eklendi";
  @override
  String get favRemoved => "Pano favorilerden çıkarıldı";
  @override
  String get newBoardTitle => "Yeni Görev Panosu Oluştur";
  @override
  String get descOptional => "Açıklama (İsteğe Bağlı)";
  @override
  String get selectTemplate => "Pano Şablonu Seçin";
  @override
  String get boardCreatedSuccess => "Görev panosu başarıyla oluşturuldu";
  @override
  String get deleteBoardTitle => "Panoyu Sil";
  @override
  String get deleteBoardConfirm => "Pano silinsin mi? Bu işlem geri alınamaz.";
  @override
  String get yesDelete => "Evet, Sil";
  @override
  String get boardNameHint => "Örn: Okul Projesi";
  @override
  String get boardNameRequired => "Lütfen pano adı giriniz";
  @override
  String get sharedWithMe => "Benimle Paylaşılan Panolar";
  @override
  String get favoritesOnly => "Sadece Favorileri Göster";
  @override
  String get allBoards => "Tüm Panoları Göster";
  @override
  String get editName => "Adını Düzenle";
  @override
  String get searchBoards => "Pano Ara";
  @override
  String get listCount => "{count} Liste";
  @override
  String get enterBoardName => "Lütfen pano adı giriniz";
  @override
  String get boardUpdateSuccess => "Pano adı güncellendi";
  @override
  String get deleteBoardSuccess => "Pano başarıyla silindi";
  @override
  String get emptyFavs => "Favori panonuz bulunmuyor.";
  @override
  String get emptyBoards => "Henüz bir görev panosu bulunmuyor\nEkranın sağ altından Pano Oluştur butonuna tıklayabilirsiniz.";
  @override
  String get pinList => "Başa Tuttur";
  @override
  String get unpinList => "Başa Tutturmayı Kaldır";
  @override
  String get listPinnedSuccess => "liste başa tutturuldu";
  @override
  String get listUnpinnedSuccess => "listenin başa tutturulması kaldırıldı";
  @override
  String get listCollapsed => "liste daraltıldı";
  @override
  String get listExpanded => "liste genişletildi";
  @override
  String get moveUp => "Yukarı Taşı";
  @override
  String get moveDown => "Aşağı Taşı";
  @override
  String get newListTitle => "Yeni Liste Ekle";
  @override
  String get listNameHint => "Örn: Yapılacaklar, Tamamlananlar";
  @override
  String get listNameRequired => "Lütfen liste adı giriniz";
  @override
  String get listCreatedSuccess => "liste oluşturuldu";
  @override
  String get addTaskTitle => "Yeni Görev Ekle";
  @override
  String get taskName => "Görev Adı";
  @override
  String get taskNameRequired => "Boş bırakılamaz";
  @override
  String get taskDesc => "Geniş Açıklama";
  @override
  String get taskAddedSuccess => "görev eklendi";
  @override
  String get inviteUser => "Üye Davet Et";
  @override
  String get inviteUserHint => "Kullanıcı adı veya e-posta adresi";
  @override
  String get inviteSuccess => "Kullanıcı başarıyla eklendi!";
  @override
  String get inviteAction => "Davet Et";
  @override
  String get emptyList => "Bu panoda henüz bir liste yok.\nSağ üst köşeden liste ekleyebilirsiniz.";
  @override
  String get completedPercentage => "Tamamlandı";
  @override
  String get noTasksInList => "Bu listede henüz görev yok.";
  @override
  String get taskDetailAction => "Düzenlemek veya görüntülemek için çift tıklayın.";
  @override
  String get taskOptionsHint => "İşlem seçenekleri için parmağınızı yukarı veya aşağı kaydırın.";
  @override
  String get listOptionsHint => "Liste ile alakalı işlem yapmak için parmağınızı yukarı ya da aşağı kaydırın.";
  @override
  String get moveListUp => "liste yukarı taşındı";
  @override
  String get moveListDown => "liste aşağı taşındı";
  @override
  String get deleteTaskConfirm => "Görevi silmek istediğinize emin misiniz?";
  @override
  String get searchCards => "Kart Ara (isim, #id veya etiket)";
  @override
  String get deleteList => "Listeyi Sil";
  @override
  String get deleteTask => "Görevi Sil";
  @override
  String get markAsCompleted => "Tamamlandı Olarak İşaretle";
  @override
  String get markAsIncomplete => "Tamamlanmadı Olarak İşaretle";
  @override
  String get timeSpentOnTask => "Toplam {time} çalışıldı.";
  @override
  String get lessThanAMinute => "1 dakikadan az";
  @override
  String get days => "gün";
  @override
  String get hours => "saat";
  @override
  String get minutes => "dakika";
  @override
  String get membersCount => "{count} Üye";
  @override
  String get deleteListConfirm => "Listeyi ve içindeki tüm görevleri silmek istediğinize emin misiniz?";
  @override
  String get deleteListTitle => "Listeyi Sil";
  @override
  String get deleteTaskTitle => "Görevi Sil";
  @override
  String get addTask => "Görev Ekle";
  @override
  String get boardMembersTitle => "Pano Üyeleri";
  @override
  String get searchMemberHint => "E-posta veya kullanıcı adı ara";
  @override
  String get boardOwner => "Pano Sahibi";
  @override
  String get noOtherMembers => "Başka üye bulunamadı.";
  @override
  String get canEditBoard => "Düzenleyebilir";
  @override
  String get canOnlyViewBoard => "Sadece Görüntüleyebilir";
  @override
  String get removeMember => "Üyeyi Çıkar";
  @override
  String get removeMemberConfirm => "Üyeyi çıkarmak istediğinize emin misiniz?";
  @override
  String get editPermission => "Yetki Düzenle";
  @override
  String get giveEditPermissionConfirm => "Düzenleme yetkisi verilsin mi?";
  @override
  String get takeEditPermissionConfirm => "Düzenleme yetkisi alınsın mı?";
  @override
  String get editPermissionSuccess => "Düzenleme yetkisi verildi";
  @override
  String get editPermissionRemoved => "Düzenleme yetkisi alındı";
  @override
  String get removeMemberSuccess => "Üye çıkarıldı";
  @override
  String get failedToChangePermission => "Yetki değiştirilemedi";
  @override
  String get failedToRemoveMember => "Üye çıkarılamadı";
  @override
  String get taskDetails => "görevin detayları";
  @override
  String get shareTask => "Kartı Paylaş";
  @override
  String get changeList => "Listeyi Değiştir";
  @override
  String get createdDate => "Oluşturulma";
  @override
  String get dueDateTarget => "Bitiş Tarihi";
  @override
  String get noDueDate => "Bitiş tarihi eklenmemiş";
  @override
  String get setDueDate => "Bitiş Tarihi Belirle";
  @override
  String get assignees => "Sorumlular";
  @override
  String get leaveResponsibility => "Sorumluluğu Bırak";
  @override
  String get makeMeResponsible => "Beni Sorumlu Yap";
  @override
  String get editDescription => "Açıklama Düzenle";
  @override
  String get noDescription => "Açıklama eklenmemiş.";
  @override
  String get addChecklistItem => "Madde Ekle";
  @override
  String get voiceNotes => "Sesli Notlar";
  @override
  String get resources => "Kaynaklar / Bağlantılar";
  @override
  String get addResource => "Yeni URL Ekle";
  @override
  String get comments => "Yorumlar";
  @override
  String get remainingDays => "{days} gün kaldı.";
  @override
  String get todayIsLastDay => "Bugün son gün.";
  @override
  String get overdueDays => "{days} gün gecikti.";
  @override
  String get setDueDateTitle => "Bitiş Tarihi Belirle";
  @override
  String get dueDateHint => "GG/AA/YYYY formatında giriniz. Örneğin 15082026.";
  @override
  String get dueDateLabel => "Bitiş Tarihi (GG/AA/YYYY)";
  @override
  String get dueDateExample => "Örn: 30/12/2026";
  @override
  String get dueDateDeleteHint => "Silmek için boş bırakıp \"Kaydet\"e basınız.";
  @override
  String get invalidDateFormat => "Geçersiz tarih formatı.";
  @override
  String get dueDateSuccess => "Bitiş tarihi eklendi.";
  @override
  String get dueDateDeleted => "Bitiş tarihi silindi.";
  @override
  String get descriptionHint => "Açıklama giriniz...";
  @override
  String get descriptionSuccess => "Açıklama güncellendi";
  @override
  String get addLabelTitle => "Etiket Ekle";
  @override
  String get labelNameLabel => "Etiket Adı";
  @override
  String get colorSelection => "renk seçimi";
  @override
  String get labelAdded => "Etiket eklendi";
  @override
  String get labelDeleted => "Etiket silindi";
  @override
  String get shareTaskTitle => "Görev Adı";
  @override
  String get shareTaskStatus => "Durum";
  @override
  String get shareTaskCreated => "Oluşturulma Tarihi";
  @override
  String get shareTaskDue => "Bitiş Tarihi";
  @override
  String get shareTaskRemaining => "Kalan Süre";
  @override
  String get shareTaskDescription => "Açıklama";
  @override
  String get shareTaskLabels => "Etiketler";
  @override
  String get shareTaskAssignees => "Sorumlular";
  @override
  String get shareTaskChecklist => "Kontrol Listesi";
  @override
  String get shareTaskResources => "Kaynaklar";
  @override
  String get shareTaskVoiceNotes => "Sesli Notlar";
  @override
  String get shareTaskVoiceNotesCount => "adet sesli not.";
  @override
  String get shareTaskStopwatch => "Görev Kronometresi";
  @override
  String get shareTaskTimeSpent => "Toplam {time} çalışıldı.";
  @override
  String get shareTaskFooter => "Blind Social - Görev Planlayıcısı ile oluşturulmuştur.";
  @override
  String get moveTaskTitle => "Listeyi Değiştir";
  @override
  String get moveTaskSuccess => "Görev taşındı";
  @override
  String get newChecklistItemTitle => "Yeni Madde";
  @override
  String get newChecklistItemLabel => "Başlık";
  @override
  String get checklistProgress => "{total} işten {completed} bitti";
  @override
  String get deleteTaskConfirmDetail => "Görevi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.";
  @override
  String get deleteTaskSuccess => "Görev başarıyla silindi";
  @override
  String get addResourceTitle => "Yeni URL Ekle";
  @override
  String get addResourceLabel => "URL Adresi";
  @override
  String get addResourceHint => "https://...";
  @override
  String get pasteFromClipboard => "Panodan Yapıştır";
  @override
  String get addResourceSuccess => "Kaynak eklendi";
  @override
  String get deleteResourceSuccess => "Kaynak silindi";
  @override
  String get copyUrlSuccess => "URL kopyalandı";
  @override
  String get copyUrlSemantics => "URL panoya kopyalandı";
  @override
  String get colorBlue => "Mavi";
  @override
  String get colorRed => "Kırmızı";
  @override
  String get colorGreen => "Yeşil";
  @override
  String get colorPurple => "Mor";
  @override
  String get colorOrange => "Turuncu";
  @override
  String get noAssignees => "Atama yapılmamış.";
  @override
  String get assigneesAssigned => "kullanıcı atandı.";
  @override
  String get noResources => "Kaynak eklenmemiş.";
  @override
  String get checklistEmpty => "Kontrol listesi boş.";
  @override
  String get taskMessagesSubtitle => "Diğer üyelerle sohbet edin.";
  @override
  String get taskMessagesSemantics => "görev için mesajlaşmaktasınız";
  @override
  List<String> get months => ["", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];

  // App Settings
  @override
  String get themeSubtitle => "Tema seçiniz";
  @override
  String get languageSubtitle => "Uygulama dilini değiştirin";
  @override
  String get notificationsSubtitle => "Ses ve titreşim ayarları";
  @override
  String get accessibilitySubtitle => "Erişilebilirlik ayarları";
  @override
  String get privacySubtitle => "Gizlilik seçenekleri";
  @override
  String get feedbackSubtitle => "Görüşlerinizi paylaşın";
  @override
  String get changelogSubtitle => "v1.7.5 - Neler yeni?";
  @override
  String get feedbackPrompt => "Lütfen görüşlerinizi paylaşın.";
  @override
  String get selectCategory => "Kategori Seçin";
  @override
  String get feedbackRequest => "İstek";
  @override
  String get feedbackSuggestion => "Öneri";
  @override
  String get feedbackComplaint => "Şikayet";
  @override
  String get feedbackThankYou => "Teşekkür";
  @override
  String get feedbackOther => "Diğer";
  @override
  String get subjectTitle => "Konu Başlığı";
  @override
  String get subjectHint => "Konuyu kısaca belirtin";
  @override
  String get maxCharacters100 => "Maks 100 karakter";
  @override
  String get yourMessage => "Mesajınız";
  @override
  String get messageHint => "Detaylı mesajınızı buraya yazın...";
  @override
  String get maxCharacters1000 => "Maks 1000 karakter";
  @override
  String get enterSubject => "Konu başlığı girin";
  @override
  String get subjectTooShort => "Konu başlığı çok kısa";
  @override
  String get enterMessage => "Mesajınızı girin";
  @override
  String get messageTooShort => "Mesaj en az 10 karakter olmalı";
  @override
  String get feedbackReceived => "Geri Bildiriminiz Alındı";
  @override
  String get feedbackThanksRedirect => "Teşekkür ederiz. Yönlendiriliyorsunuz...";
  @override
  String get returnNow => "Hemen Dön";
  @override
  String get dropdownAccessibilityHint => "Seçenekleri görmek için çift tıklayın";
  @override
  String get friendRequestsAndBlocks => "Arkadaşlık ve Engellenenler";
  @override
  String get incomingRequestsHeader => "Gelen İstekler";
  @override
  String get noIncomingRequests => "Gelen istek yok.";
  @override
  String get outgoingRequestsHeader => "Giden İstekler";
  @override
  String get noOutgoingRequests => "Giden istek yok.";
  @override
  String get blockedUsersHeader => "Engellenenler";
  @override
  String get noBlockedUsers => "Engellenen kullanıcı yok.";
  @override
  String get friendRequestAccepted => "İstek kabul edildi.";
  @override
  String get friendRequestRejected => "İstek reddedildi.";
  @override
  String get userUnblocked => "Engel kaldırıldı.";
  @override
  String get unnamed => "İsimsiz";
  @override
  String get friendRequestFrom => "den gelen istek";
  @override
  String get friendRequestTo => "ye gönderilen istek. İptal etmek için tıklayın.";
  @override
  String get cancelOutgoingRequest => "İsteği iptal et";
  @override
  String get blockedUserInfo => "Engellenen kullanıcı. Engeli kaldırmak için tıklayın.";
  @override
  String get unblockUserTooltip => "Engeli kaldır";
  @override
  String get messageNotifications => "Mesaj Bildirimleri";
  @override
  String get sound => "Ses";
  @override
  String get messageSoundSubtitle => "Yeni mesaj sesi";
  @override
  String get vibration => "Titreşim";
  @override
  String get messageVibrationSubtitle => "Yeni mesaj titreşimi";
  @override
  String get callNotifications => "Arama Bildirimleri";
  @override
  String get ringtone => "Zil Sesi";
  @override
  String get callSoundSubtitle => "Arama sesi";
  @override
  String get callVibrationSubtitle => "Arama titreşimi";
  @override
  String get screenProtection => "Ekran Kaydı Koruması";
  @override
  String get screenProtectionSubtitle => "Ekran görüntüsünü/kaydını engeller";
  @override
  String get showOnLockScreen => "Kilit Ekranında Göster";
  @override
  String get showOnLockScreenSubtitle => "Ekran kilitliyken görünürlük";
  @override
  String get fullnamePrivacy => "Ad Soyad Gizliliği";
  @override
  String get whoCanSeeThis => "Kimler görebilir?";
  @override
  String get everyone => "Herkes";
  @override
  String get friends => "Arkadaşlar";
  @override
  String get nobody => "Hiç Kimse";
  @override
  String get fullnamePrivacySemantics => "Ad soyad gizlilik ayarı";
  @override
  String get lastSeen => "Son Görülme";
  @override
  String get lastSeenSubtitle => "Son görülme zamanını paylaş";
  @override
  String get birthday => "Doğum Tarihi";
  @override
  String get birthdayPrivacySemantics => "Doğum tarihi gizlilik ayarı";
  @override
  String get privacyFooter => "Gizlilik ayarları uygulama güvenliğinizi sağlar.";
  @override
  String get profileInfo => "Profil Bilgileri";
  @override
  String get profileLoadError => "Profil yüklenemedi";
  @override
  String get removeFromFriends => "Arkadaşlıktan Çıkar";
  @override
  String get removedFromFriends => "Arkadaşlıktan çıkarıldı.";
  @override
  String get blockUser => "Engelle";
  @override
  String get userBlocked => "Kullanıcı engellendi.";
  @override
  String get operationFailed => "İşlem başarısız";
  @override
  String get userNotFound => "Kullanıcı bulunamadı.";
  @override
  String get unspecified => "Belirtilmemiş";
  @override
  String get hidden => "Gizli";
  @override
  String get lastSeenUnknown => "Son görülme bilinmiyor";
  @override
  String get currentlyActive => "Şu an aktif";
  @override
  String get userProfilePhoto => "profil fotoğrafı";
  @override
  String get about => "Hakkında";
  @override
  String get details => "Detaylar";
  @override
  String get joined => "Katılım";
  @override
  String get addAsFriend => "Arkadaş Ekle";
  @override
  String get youAreFriends => "Arkadaşsınız";
  @override
  String get friendRequestSent => "İstek Gönderildi";
  @override
  String get wantsToAddYou => "Sizi Eklemek İstiyor";
  @override
  String get friendRequestSentSuccess => "İstek gönderildi!";
  @override
  String get noPermissionView => "Görüntüleme yetkiniz yok.";
  @override
  String get latest => "En Yeni";
  @override
  String get taskOverview => "Görev Özeti";
  @override
  String get total => "Toplam";
  @override
  String get myPendingTasks => "Bekleyen Görevlerim";
  @override
  String get myCompletedTasks => "Tamamlanan Görevlerim";
  @override
  String get noPendingTasksFound => "Bekleyen görev yok";
  @override
  String get noCompletedTasksFound => "Tamamlanan görev yok";
  @override
  String taskOverviewAnnouncement(int total, int completed, int pending) => "Toplam $total görevden $completed tamamlandı, $pending bekliyor.";
  @override
  String taskOverviewStatsLabel(int total, int completed, int pending) => "Toplam: $total, Tamamlanan: $completed, Bekleyen: $pending";
  @override
  String get notInFavorites => "Favorilerde Değil";
  @override
  String boardAnnouncement(String name, String favText, int listCount, bool isOwner) => "Pano: $name, Liste sayısı: $listCount, $favText";
  @override
  String boardDetailAnnouncement(String name) => "$name panosu detay sayfası";
  @override
  String get boardOptionsHint => "Seçenekler için çift tıklayın";
  @override
  String get dropdownHint => "Seçenek seçin";
  @override
  String get activeNow => "Aktif";
  @override
  String get statusFailed => "Durum Başarısız";
  @override
  String get accept => "Kabul Et";
  @override
  String get reject => "Reddet";
  @override
  String get exitAppTitle => "Çıkış";
  @override
  String get exitAppConfirm => "Çıkmak istediğinize emin misiniz?";
  @override
  String get exit => "Çıkış";
  @override
  String get newChatTooltip => "Yeni Sohbet";
  @override
  String get newServerTooltip => "Yeni Sunucu";
  @override
  String get serverNameLabel => "Sunucu Adı";
  @override
  String get serverNameHint => "Sunucu adı girin";
  @override
  String get serverNameRequired => "Gerekli";
  @override
  String get serverNameTooShort => "Çok kısa";
  @override
  String get serverPasswordLabel => "Sunucu Şifresi";
  @override
  String get serverPasswordHint => "Şifre girin";
  @override
  String get serverCreatedSuccess => "Sunucu oluşturuldu";
  @override
  String get serverNameMinLength => "En az 3 karakter";
  @override
  String get serverLimitReached => "Limit aşıldı";
  @override
  String get serverLimitDaily => "Günlük limit aşıldı";
  @override
  String get serverCreateGenericError => "Hata oluştu";
  @override
  String get unnamedChat => "İsimsiz Kanal";
  @override
  String get reply => "Yanıtla";
  @override
  String get speakerSet => "Hoparlör ayarlandı";
  @override
  String get voiceSentStatus => "Ses Gönderildi";
  @override
  String get addToFavs => "Favorilere Ekle";
  @override
  String get removeFromFavs => "Favorilerden Çıkar";
  @override
  String get voiceCall => "Sesli Arama";
  @override
  String get videoCall => "Görüntülü Arama";
  @override
  String get privateChat => "Özel Sohbet";
  @override
  String get servers => "Sunucular";
  @override
  String get noMessagesYet => "Mesaj yok";
  @override
  String get unreadMessageSuffix => "okunmamış mesaj";
  @override
  String get outgoingCallUnanswered => "Yanıtlanmadı";
  @override
  String get callAccepted => "Arama Kabul Edildi";
  @override
  String get callAcceptedByYou => "Arama Kabul Edildi";
  @override
  String get callRejected => "Arama Reddedildi";
  @override
  String get callRejectedByYou => "Arama Reddedildi";
  @override
  String get callCancelled => "Arama İptal Edildi";
  @override
  String get callCancelledByYou => "Arama İptal Edildi";
  @override
  String get starred => "Yıldızlı";
  @override
  String get repliedMessage => "Yanıtlanan Mesaj";
  @override
  String get yourVoiceMessage => "Sesli Mesajınız";

  // Campaigns
  @override
  String get campaigns => "Kampanyalar";
  @override
  String get categories => "Kategoriler";
  @override
  String get all => "Hepsi";
  @override
  String get searchCampaign => "Ara";
  @override
  String get noCampaignFound => "Kampanya yok";
  @override
  String get viewOnWeb => "Web'de görüntüle";
  @override
  String get shareCampaign => "Paylaş";
  @override
  String get inspectingCategory => "Kategori:";
  @override
  String get campaignParticipation => "Katılım";
  @override
  String get earningsUsage => "Kazanım Kullanımı";
  @override
  String get includedBrands => "Markalar";
  @override
  String get otherCampaignsForBrand => "Diğer kampanyalar";
  @override
  String get showLess => "Daha Az";
  @override
  String get showAll => "Tümü";
  @override
  String get campaignConditions => "Koşullar";
  @override
  String get startDate => "Başlangıç";
  @override
  String get endDate => "Bitiş";

  // Errors
  @override
  String get connectionError => "Bağlantı hatası";
  @override
  String get genericError => "Bir hata oluştu";
  @override
  String get accessDenied => "Erişim Reddedildi";

  @override
  String get admin => "Yönetici";
  @override
  String get capacityLabel => "Kapasite";
  @override
  String get chatArchivedStatus => "Arşivlendi";
  @override
  String get chatPinnedStatus => "Başa tutturuldu";
  @override
  String get chatUnarchivedStatus => "Arşivden çıkarıldı";
  @override
  String get chatUnpinnedStatus => "Baştan kaldırıldı";
  @override
  String get connectionErrorWithStatus => "Bağlantı Hatası: ";
  @override
  String get create => "Oluştur";
  @override
  String get createServerTitle => "Sunucu Oluştur";
  @override
  String get deleteMessage => "Mesajı Sil";
  @override
  String get duration => "Süre";
  @override
  String get earpieceSet => "Ahize modu aktif";
  @override
  String get editMessage => "Mesajı Düzenle";
  @override
  String get editMessageHint => "Mesajınızı yazın...";
  @override
  String get editMessageTitle => "Mesajı Düzenle";
  @override
  String get edited => "Düzenlendi";
  @override
  String get emptyChatList => "Sohbet bulunamadı";
  @override
  String get failedToLoadDetails => "Detaylar yüklenemedi";
  @override
  String get favAddedStatus => "Favorilere eklendi";
  @override
  String get favRemovedStatus => "Favorilerden çıkarıldı";
  @override
  String get favoriteMessages => "Favori Mesajlar";
  @override
  String get archivedChats => "Arşivlenmiş Sohbetler";
  @override
  String get gameInviteDesc => "Seni bir oyun oynamaya davet ettim!";
  @override
  String get gameInviteTitle => "Oyun Daveti";
  @override
  String get generalStats => "Genel İstatistikler";
  @override
  String get group => "Grup";
  @override
  String get headsetOrBluetoothSet => "Kulaklık/Bluetooth bağlandı";
  @override
  String get inFavorites => "Favorilerde";
  @override
  String get incomingVideoCall => "Gelen görüntülü arama";
  @override
  String get incomingVoiceCall => "Gelen sesli arama";
  @override
  String get incomingVoiceMessage => "Gelen sesli mesaj";
  @override
  String get lineBusy => "Hat meşgul";
  @override
  String get liveVoiceRoom => "Canlı Ses Odası";
  @override
  String get messageDeletedStatus => "Mesaj silindi";
  @override
  String get messageSentStatus => "Mesaj gönderildi";
  @override
  String get microphoneAccessDenied => "Mikrofon izni reddedildi";
  @override
  String get missedCall => "Cevapsız arama";
  @override
  String get missedVideoCall => "Cevapsız görüntülü arama";
  @override
  String get outgoingVideoCall => "Giden görüntülü arama";
  @override
  String get outgoingVoiceCall => "Giden sesli arama";
  @override
  String get securitySettings => "Güvenlik Ayarları";
  @override
  String get blog => "Blog";
  @override
  String voiceRoomCapacity(String value) => "Kapasite: $value";
  @override
  String get lastSeenHidden => "Son görülme gizli";
  @override
  String get lastSeenToday => "Bugün şu saatte görüldü:";
  @override
  String get no => "Hayır";
  @override
  String get yes => "Evet";
  @override
  String get typeMessage => "Mesajınızı yazın...";
  @override
  String get you => "Sen";
  @override
  String get replied => "Yanıt verildi";
  @override
  String get replyingTo => "Yanıtlanıyor:";
  @override
  String get callLog => "Arama Kaydı";
  @override
  String get sendFeedback => "Geri Bildirim Gönder";
  @override
  String get emptyTemplate => "Boş Şablon";
  @override
  String get softwareDevTemplate => "Yazılım Geliştirme";
  @override
  String get dailyTasksTemplate => "Günlük Görevler";
  @override
  String get projectMgmtTemplate => "Proje Yönetimi";
  @override
  String get openBoard => "Panoyu Aç";
  @override
  String get currentlySpeaking => "şu an konuşuyor";
  @override
  String get deleteListSuccess => "liste silindi";
  @override
  String get tasks => "görevler";
  @override
  String get options => "Seçenekler";
  @override
  String get task => "Görev";
  @override
  String get january => "Ocak";
  @override
  String get february => "Şubat";
  @override
  String get march => "Mart";
  @override
  String get april => "Nisan";
  @override
  String get may => "Mayıs";
  @override
  String get june => "Haziran";
  @override
  String get july => "Temmuz";
  @override
  String get august => "Ağustos";
  @override
  String get september => "Eylül";
  @override
  String get october => "Ekim";
  @override
  String get november => "Kasım";
  @override
  String get december => "Aralık";
  @override
  String get permission => "İzin";
  @override
  String get add => "Ekle";
  @override
  String get delete => "Sil";
  @override
  String get label => "Etiket";
  @override
  String get statusUpdated => "Durum güncellendi";
  @override
  String get checklistTitle => "Kontrol Listesi";
  @override
  String get copy => "Kopyala";
  @override
  String get deleteComment => "Yorumu Sil";
  @override
  String get editPost => "Gönderiyi Düzenle";
  @override
  String get deletePost => "Gönderiyi Sil";
  @override
  String get unlikePost => "Beğeniyi Kaldır";
  @override
  String get likePost => "Beğen";
  @override
  String get openComments => "Yorumları Aç";
  @override
  String get deleteVoiceNote => "Kaydı Sil";
  @override
  String get playRecording => "Kaydı Oynat";
  @override
  String get deleteRoom => "Odayı Sil";
  @override
  String get kickUser => "Sunucudan At";
  @override
  String get banUser => "Kullanıcıyı Yasakla";
  @override
  String get unbanUser => "Yasak listesinden çıkar";
  @override
  @override
  String get playRecordAnnounce => "Kayıt oynatılıyor";
  @override
  String get deleteCommentConfirm => "Bu yorumu silmek istediğinize emin misiniz?";
  @override
  String get commentDeleted => "Yorum silindi";
  @override
  String get commentSent => "Yorum gönderildi";
  @override
  String get sendingVoiceComment => "Sesli yorum gönderiliyor...";
  @override
  String get voiceCommentSent => "Sesli yorum gönderildi";
  @override
  String get noComments => "Henüz yorum yok. İlk yorum yapan siz olun!";
  @override
  String get stopVoiceMessage => "Sesli Mesajı Durdur";
  @override
  String get playVoiceMessage => "Sesli Mesajı Oynat";
  @override
  String get incomplete => "Tamamlanmadı";
  @override
  String statusTodayAt(String time) => "Bugün $time";
  @override
  String statusLastSeen(String date) => "Son görülme: $date";
  @override
  String get user => "Kullanıcı";
  @override
  String unreadMessagesCount(int count) => "$count okunmamış mesaj";
  @override
  String get incomingMessage => "Gelen mesaj";
  @override
  String get onlyAdminCanSendMessages => "Sadece yöneticiler mesaj gönderebilir";
  @override
  @override
  String get noVoiceNotesAdded => "Sesli not eklenmemiş.";
  @override
  String get recordNewVoiceNote => "Yeni Sesli Not Kaydet (Max 5 dk)";
  @override
  String get voiceNote => "Sesli Not";
  @override
  String get deleteThisVoiceNote => "Bu sesli notu sil";
  @override
  String get voiceRecorderInitError => "Ses kaydedici başlatılamadı: ";
  @override
  String get voiceNoteSavedSuccessfully => "Sesli not başarıyla kaydedildi.";
  @override
  String get voiceNoteUploadError => "Ses notu yüklenemedi: ";
  @override
  String get voiceNoteDeleted => "Sesli not silindi.";
  @override
  String get voiceNoteDeleteError => "Ses notu silinemedi: ";
  @override
  String get voiceNotePlayError => "Ses notu oynatılamadı: ";

  @override
  String get taskStopwatch => "Görev Kronometresi";
  @override
  String get stopStopwatch => "Kronometreyi Durdur";
  @override
  String get startStopwatch => "Kronometreyi Başlat";
  @override
  String get startNewStopwatch => "Yeni Kronometre Başlat";
  @override
  String get stopwatchStarted => "Kronometre başlatıldı";
  @override
  String get stopwatchStopped => "Kronometre durduruldu";

  @override
  String get socialSection => "Sosyal";
  @override
  String get friendAndBlockedList => "Arkadaşlık ve Engellenenler Listesi";
  @override
  String get gamesArea => "Oyun Alanı";
  @override
  String get contentAndToolsSection => "İçerik ve Araçlar";
  @override
  String get liveRadio => "Canlı Radyo";
  @override
  String get tools => "Araçlar";
  @override
  String get systemSection => "Sistem";
  @override
  String get administrationSection => "Yönetim";
  @override
  String get adminPanel => "Yönetici Paneli";
  @override
  String get developerModeLogs => "Geliştirici Modu / Loglar";

  // Semantics & Actions
  @override
  String get viewProfile => "Profili Görüntüle";
  @override
  String get unarchiveChat => "Arşivden Çıkar";
  @override
  String get archiveChat => "Arşivle";
  @override
  String get unpinChat => "Sabitlemeden Çıkar";
  @override
  String get pinChat => "Sabitle";
  @override
  String get deleteChat => "Sohbeti Sil";
  @override
  @override
  String get kickFromServer => "Sunucudan At";
  @override
  @override
  @override
  String serverSemanticLabel(String serverName, String description, String capacity, String encryptedText, String onlineCount) =>
      "Sunucu adı $serverName. Sunucu açıklaması $description. $capacity kişilik $encryptedText sunucu. Şu anda sunucuda $onlineCount kişi var.";
  @override
  String get joinServerHint => "Sunucuya katılmak için çift tıklayın";
  @override
  String joinedServerAnnounce(String serverName) => "Şu anda $serverName isimli sunucuya bağlandınız.";
  @override
  String get doubleTapToSeeOptionsHint => "Seçenekleri görmek ve değiştirmek için çift tıklayın";
  @override
  String roomCreatedAnnounce(String roomName) => "$roomName isimli oda başarıyla oluşturulmuştur.";
  @override
  String roomSemanticLabel(String roomName, String roomType) => "$roomName isimli $roomType";
  @override
  String get joinRoomHint => "Odaya girmek için çift tıklayın";
  @override
  String get roomsTabCreatorHint => "Odalar sekmesi. Odaları silmek için ilgili odanın üzerindeyken işlemler menüsünden odayı sil seçeneğini kullanabilirsiniz (tek parmakla yukarı ve aşağı kaydırarak).";
  @override
  String get roomsTabHint => "Odalar sekmesi";
  @override
  String get messageReactionSemantic => "Mesaja durum ifadesi bırak";
  @override
  @override
  String get shareRecording => "Kaydı Paylaş";
  @override
  String get removeRecording => "Kaydı Sil";
  @override
  String get deleteLog => "Çalışma Süresini Sil";

  // Additional found items
  @override
  String errorLabel(String errorMsg) => "Hata: $errorMsg";
  @override
  String get workHistory => "Çalışma Geçmişi";
  @override
  String get lessThanOneMinute => "1 dakikadan az";
  @override
  String get daysSuffix => "gün";
  @override
  String get hoursSuffix => "saat";
  @override
  String get minutesSuffix => "dakika";
  @override
  String get recordingStarted => "Kayıt başladı";
  @override
  String get recordingPaused => "Kayıt duraklatıldı";
  @override
  String get recordingResumed => "Kayda devam ediliyor";
  @override
  String get recordingCancelled => "Kayıt iptal edildi";
  @override
  String get recordingStopped => "Kayıt durduruldu";
  @override
  String get voiceNoteSaved => "Sesli not başarıyla kaydedildi.";
  @override
  String get cancelBtn => "İptal Et";
  @override
  String get finishBtn => "Bitir";
  @override
  String playRadioError(String stationName) => "$stationName oynatılamadı. Bağlantı hatası.";
  @override
  String get sleepTimerCancelled => "Uyku zamanlayıcısı iptal edildi.";
  @override
  String get sleepTimerExpired => "Uyku zamanlayıcısı süresi doldu. Yayın durduruldu.";
  @override
  String sleepTimerSet(String minutes) => "Uyku zamanlayıcısı $minutes dakikaya ayarlandı.";
  @override
  String get cancelTimerBtn => "Zamanlayıcıyı İptal Et";
  @override
  String recordingCompleted(String stationName) => "Kayıt tamamlandı: $stationName";
  @override
  String get recordingStoppedAndSaved => "Kayıt durduruldu ve kaydedildi";
  @override
  String get recordingInit => "Kayıt başlatıldı...";
  @override
  String get liveRadioRecordingStarted => "Canlı yayın kaydı başlatıldı";
  @override
  String get savedRecordingsTitle => "Kaydedilen Yayınlar";
  @override
  String get noSavedRecordings => "Henüz kaydedilmiş yayın yok.";
  @override
  String get permanentlyDeleteNotice => "Bu kaydı telefonunuzdan kalıcı olarak silmek istediğinize emin misiniz?";
  @override
  String get cancelUppercase => "İPTAL";
  @override
  String get deleteUppercase => "SİL";
  @override
  String get shareError => "Paylaşma hatası";
  @override
  String get deleteRecording => "Kaydı Sil";
  @override
  String get ongoingWork => "Devam Eden Çalışma";
  @override
  String get completedWork => "Tamamlanan Çalışma";
}

