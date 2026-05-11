import 'language.dart';

class LanguageEn extends BaseLanguage {
  @override
  String get appName => "Blind Social";
  @override
  String get ok => "OK";
  @override
  String get cancel => "Cancel";
  @override
  String get save => "Save";
  @override
  String get error => "Error";
  @override
  String get loading => "Loading...";
  @override
  String get noData => "No data found";
  @override
  String get tryAgain => "Try Again";
  @override
  String get unknown => "Unknown";
  @override
  String get notSpecified => "Not specified";

  @override
  String get login => "Login";
  @override
  String get logout => "Logout";
  @override
  String get email => "Email";
  @override
  String get password => "Password";
  @override
  String get username => "Username";
  @override
  String get fullName => "Full Name";
  @override
  String get forgotPassword => "Forgot Password?";
  @override
  String get signUp => "Sign Up";
  @override
  String get welcomeBack => "Welcome Back";
  @override
  String get signOutAccount => "Sign Out of Account";

  @override
  String get profile => "Profile";
  @override
  String get editProfile => "Edit Profile";
  @override
  String get saveChanges => "Save Changes";
  @override
  String get deleteAccount => "Delete My Account";
  @override
  String get deleteAccountConfirm => "Are you sure you want to delete your account?";
  @override
  String get deleteAccountWarning => "This action cannot be undone and all your data will be permanently deleted.";
  @override
  String get updatingProfile => "Updating profile...";
  @override
  String get invalidName => "Please enter a valid name.";
  @override
  String get invalidUsername => "Please enter a valid username.";
  @override
  String get settings => "Settings";
  @override
  String get bio => "Bio";
  @override
  String get dob => "Date of Birth";
  @override
  String get joinedAt => "Joined";
  @override
  String get myProfile => "My Profile";
  @override
  String get userProfile => "User Profile";
  @override
  String get personalInfo => "Personal Information";
  @override
  String get profilePhoto => "Profile photo";
  @override
  String get noBio => "No bio added yet.";
  @override
  String get profileUpdateSuccess => "Profile updated successfully.";
  @override
  String get bioHint => "Tell us about yourself...";
  @override
  String get fullNameHint => "Enter your full name";
  @override
  String get contactSupportForChange => "Note: Contact support to change username or email address.";

  @override
  String get appSettings => "App Settings";
  @override
  String get accessibility => "Accessibility";
  @override
  String get theme => "Theme";
  @override
  String get language => "Language";
  @override
  String get fontSize => "Font Size";
  @override
  String get notifications => "Notifications";
  @override
  String get privacy => "Privacy";
  @override
  String get changelog => "Changelog";
  @override
  String get feedback => "Feedback";
  @override
  String get systemTheme => "System Theme";
  @override
  String get lightTheme => "Light Theme";
  @override
  String get darkTheme => "Dark Theme";
  @override
  String get themeDesc => "Changes based on device settings";
  @override
  String get voiceRoomNotif => "Voice Room Notifications";
  @override
  String get voiceRoomNotifDesc => "Notify about users joining/leaving voice rooms";
  @override
  String get small => "Small";
  @override
  String get normal => "Normal";
  @override
  String get large => "Large";
  @override
  String get extraLarge => "Extra Large";
  @override
  String get fontSizeDesc => "Adjust the size of text throughout the app";
  @override
  String get fontSizeExample => "Sample Text: This setting affects all text throughout the app. You can choose the size that best suits your reading comfort.";

  @override
  String get campaigns => "Campaigns";
  @override
  String get all => "All";
  @override
  String get searchCampaign => "Search campaigns";
  @override
  String get noCampaignFound => "No campaigns found";
  @override
  String get viewOnWeb => "View on web page";
  @override
  String get shareCampaign => "Share Campaign";
  @override
  String get inspectingCategory => " category browsing.";
  @override
  String get campaignParticipation => "CAMPAIGN PARTICIPATION";
  @override
  String get earningsUsage => "EARNINGS USAGE";
  @override
  String get includedBrands => "Included Brands";
  @override
  String get otherCampaignsForBrand => " Tap to view other campaigns for ";
  @override
  String get showLess => "Show Less";
  @override
  String get showAll => "Show All";
  @override
  String get campaignConditions => "Campaign Conditions";
  @override
  String get startDate => "Start date";
  @override
  String get endDate => "End date";

  @override
  String get taskBoard => "Task Board";
  @override
  String get myBoards => "My Boards";
  @override
  String get createBoard => "Create Board";
  @override
  String get boardName => "Board Name";
  @override
  String get boardStats => "Board Statistics";
  @override
  String get addCard => "Add Card";
  @override
  String get addList => "Add List";
  @override
  String get members => "Members";
  @override
  String get checklist => "Checklist";
  @override
  String get tags => "Tags";
  @override
  String get completed => "Completed";
  @override
  String get pending => "Pending";
  @override
  String get totalTasksInCount => "{completed} completed out of total {total} tasks";
  @override
  String get taskDetail => "Task Detail";
  @override
  String get boardMembers => "Board Members";
  @override
  String get overview => "Overview";
  @override
  String get description => "Description";

  @override
  String get boardFilterAll => "All boards are listed";
  @override
  String get boardFilterMy => "Only your own boards are listed";
  @override
  String get boardFilterShared => "Only boards shared with you are listed";
  @override
  String get favAdded => "Board added to favorites";
  @override
  String get favRemoved => "Board removed from favorites";
  @override
  String get newBoardTitle => "Create New Task Board";
  @override
  String get descOptional => "Description (Optional)";
  @override
  String get selectTemplate => "Select Board Template";
  @override
  String get boardCreatedSuccess => "Task board successfully created";
  @override
  String get deleteBoardTitle => "Delete Board";
  @override
  String get deleteBoardConfirm => "Are you sure you want to delete board? This action cannot be undone.";
  @override
  String get yesDelete => "Yes, Delete";
  @override
  String get boardNameHint => "e.g. School Project";
  @override
  String get boardNameRequired => "Please enter board name";
  @override
  String get sharedWithMe => "Shared With Me";
  @override
  String get favoritesOnly => "Show Favorites Only";
  @override
  String get allBoards => "Show All Boards";
  @override
  String get editName => "Edit Name";
  @override
  String get searchBoards => "Search Boards";
  @override
  String get listCount => "{count} Lists";
  @override
  String get enterBoardName => "Please enter board name";
  @override
  String get boardUpdateSuccess => "Board name updated";
  @override
  String get deleteBoardSuccess => "Board successfully deleted";
  @override
  String get emptyFavs => "You have no favorite boards.";
  @override
  String get emptyBoards => "No task boards found yet\nYou can click the Create Board button at the bottom right.";

  @override
  String get pinList => "Pin to Top";
  @override
  String get unpinList => "Unpin from Top";
  @override
  String get listPinnedSuccess => "list pinned to top";
  @override
  String get listUnpinnedSuccess => "list unpinned from top";
  @override
  String get listCollapsed => "list collapsed";
  @override
  String get listExpanded => "list expanded";
  @override
  String get moveUp => "Move Up";
  @override
  String get moveDown => "Move Down";
  @override
  String get newListTitle => "Add New List";
  @override
  String get listNameHint => "e.g. To Do, Finished";
  @override
  String get listNameRequired => "Please enter list name";
  @override
  String get listCreatedSuccess => "list created";
  @override
  String get addTaskTitle => "Add New Task";
  @override
  String get taskName => "Task Name";
  @override
  String get taskNameRequired => "Cannot be empty";
  @override
  String get taskDesc => "Detailed Description";
  @override
  String get taskAddedSuccess => "task added";
  @override
  String get inviteUser => "Invite Member";
  @override
  String get inviteUserHint => "Username or email address";
  @override
  String get inviteSuccess => "User added successfully!";
  @override
  String get inviteAction => "Invite";
  @override
  String get emptyList => "There are no lists in this board yet.\nYou can add a list from the top right corner.";
  @override
  String get completedPercentage => "Completed";
  @override
  String get noTasksInList => "No tasks in this list yet.";
  @override
  String get taskDetailAction => "Double click to edit or view.";
  @override
  String get taskOptionsHint => "Swipe up or down for task options.";
  @override
  String get listOptionsHint => "Swipe up or down for list options.";
  @override
  String get moveListUp => "list moved up";
  @override
  String get moveListDown => "list moved down";
  @override
  String get deleteTaskConfirm => "Are you sure you want to delete task?";
  @override
  String get searchCards => "Search Cards (name, #id or tag)";
  @override
  String get deleteList => "Delete List";
  @override
  String get deleteTask => "Delete Task";
  @override
  String get markAsCompleted => "Mark as Completed";
  @override
  String get markAsIncomplete => "Mark as Incompleted";
  @override
  String get timeSpentOnTask => "Total {time} spent on this task.";
  @override
  String get lessThanAMinute => "less than a minute";
  @override
  String get days => "days";
  @override
  String get hours => "hours";
  @override
  String get minutes => "minutes";
  @override
  String get membersCount => "{count} Members";
  @override
  String get deleteListConfirm => "Are you sure you want to delete list and all its tasks?";
  @override
  String get deleteListTitle => "Delete List";
  @override
  String get deleteTaskTitle => "Delete Task";
  @override
  String get addTask => "Add Task";
  @override
  String get boardMembersTitle => "Board Members";
  @override
  String get searchMemberHint => "Search email or username";
  @override
  String get boardOwner => "Board Owner";
  @override
  String get members => "Members";
  @override
  String get noOtherMembers => "No other members found.";
  @override
  String get canEditBoard => "Can Edit Board";
  @override
  String get canOnlyViewBoard => "Can Only View Board";
  @override
  String get removeMember => "Remove Member";
  @override
  String get removeMemberConfirm => "Are you sure you want to remove member from board?";
  @override
  String get editPermission => "Edit Permission";
  @override
  String get giveEditPermissionConfirm => "Do you want to give edit permission to user?";
  @override
  String get takeEditPermissionConfirm => "Do you want to take away edit permission from user?";
  @override
  String get editPermissionSuccess => "Edit permission granted to user";
  @override
  String get editPermissionRemoved => "Edit permission removed from user";
  @override
  String get removeMemberSuccess => "member removed from board";
  @override
  String get failedToChangePermission => "Failed to change permission";
  @override
  String get failedToRemoveMember => "Failed to remove member";
  @override
  String get taskDetails => "details of task named";
  @override
  String get shareTask => "Share Card";
  @override
  String get changeList => "Change List";
  @override
  String get createdDate => "Created";
  @override
  String get dueDateTarget => "Due Date (Target)";
  @override
  String get noDueDate => "No due date set";
  @override
  String get setDueDate => "Set Due Date";
  @override
  String get assignees => "Assignees";
  @override
  String get leaveResponsibility => "Leave Responsibility";
  @override
  String get makeMeResponsible => "Make Me Responsible";
  @override
  String get description => "Description";
  @override
  String get editDescription => "Edit Description";
  @override
  String get noDescription => "No description added yet.";
  @override
  String get checklist => "Checklist";
  @override
  String get addChecklistItem => "Add Item";
  @override
  String get voiceNotes => "Voice Notes";
  @override
  String get resources => "Resources / Links";
  @override
  String get addResource => "Add New URL";
  @override
  String get comments => "Comments";
  @override
  String get remainingDays => "{days} days remaining to complete this task.";
  @override
  String get todayIsLastDay => "Today is the last day to complete this task.";
  @override
  String get overdueDays => "This task is {days} days overdue.";
  @override
  String get setDueDateTitle => "Set Due Date";
  @override
  String get dueDateHint => "Enter due date as day, month, and year with slashes. If you don't use slashes, the system will add them automatically. For example, 15082026.";
  @override
  String get dueDateLabel => "Due Date (DD/MM/YYYY)";
  @override
  String get dueDateExample => "E.g.: 30/12/2026 or 30122026";
  @override
  String get dueDateDeleteHint => "To delete, leave field blank and press \"Save\".";
  @override
  String get invalidDateFormat => "Invalid date format. Please enter as DD/MM/YYYY.";
  @override
  String get dueDateSuccess => "Due date successfully added.";
  @override
  String get dueDateDeleted => "Due date deleted.";
  @override
  String get descriptionHint => "Enter description...";
  @override
  String get descriptionSuccess => "Description updated";
  @override
  String get addLabelTitle => "Add Label";
  @override
  String get labelNameLabel => "Label Name";
  @override
  String get colorSelection => "color selection";
  @override
  String get labelAdded => "Label added";
  @override
  String get labelDeleted => "Label deleted";
  @override
  String get shareTaskTitle => "Task Title";
  @override
  String get shareTaskStatus => "Status";
  @override
  String get shareTaskCreated => "Created Date";
  @override
  String get shareTaskDue => "Due Date (Target)";
  @override
  String get shareTaskRemaining => "Remaining Time";
  @override
  String get shareTaskDescription => "Description";
  @override
  String get shareTaskLabels => "Labels";
  @override
  String get shareTaskAssignees => "Assignees";
  @override
  String get shareTaskChecklist => "Checklist";
  @override
  String get shareTaskResources => "Resources";
  @override
  String get shareTaskVoiceNotes => "Voice Notes";
  @override
  String get shareTaskVoiceNotesCount => "voice notes available.";
  @override
  String get shareTaskStopwatch => "Task Stopwatch";
  @override
  String get shareTaskTimeSpent => "Total time spent on this task: {time}";
  @override
  String get shareTaskFooter => "Created with Blind Social - Task Planner.";
  @override
  String get moveTaskTitle => "Change List";
  @override
  String get moveTaskSuccess => "Task moved to another list";
  @override
  String get newChecklistItemTitle => "New Checklist Item";
  @override
  String get newChecklistItemLabel => "Title";
  @override
  String get checklistProgress => "{completed} of {total} items completed, {percentage}% done";
  @override
  String get deleteTaskConfirmDetail => "Are you sure you want to delete this task? This action cannot be undone and all data related to the task (voice recordings, notes, etc.) will be deleted.";
  @override
  String get deleteTaskSuccess => "Task successfully deleted";
  @override
  String get addResourceTitle => "Add New URL/Resource";
  @override
  String get addResourceLabel => "URL Address";
  @override
  String get addResourceHint => "https://...";
  @override
  String get pasteFromClipboard => "Paste from Clipboard";
  @override
  String get addResourceSuccess => "Resource added";
  @override
  String get deleteResourceSuccess => "Resource deleted";
  @override
  String get copyUrlSuccess => "URL copied";
  @override
  String get copyUrlSemantics => "URL copied to clipboard";
  @override
  String get colorBlue => "Blue";
  @override
  String get colorRed => "Red";
  @override
  String get colorGreen => "Green";
  @override
  String get colorPurple => "Purple";
  @override
  String get colorOrange => "Orange";
  @override
  String get noAssignees => "No one has been assigned to this task yet.";
  @override
  String get assigneesAssigned => "users are assigned to this task.";
  @override
  String get noResources => "No resources added yet.";
  @override
  String get checklistEmpty => "Checklist is empty.";
  @override
  String get taskMessagesSubtitle => "Chat with other members or leave a voice message.";
  @override
  String get taskMessagesSemantics => "You are messaging for the task named";
  @override
  List<String> get months => ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

  // App Settings
  @override
  String get themeSubtitle => "Choose light, dark or system theme";
  @override
  String get languageSubtitle => "Change the application language";
  @override
  String get notificationsSubtitle => "Manage sound and vibration settings";
  @override
  String get accessibilitySubtitle => "Screen reader and assistance features";
  @override
  String get privacySubtitle => "Screen protection and lock screen options";
  @override
  String get feedbackSubtitle => "Share your views with us";
  @override
  String get changelogSubtitle => "v1.7.5 - What's new?";
  @override
  String get feedbackPrompt => "Please share your views with us so that we can serve you better.";
  @override
  String get selectCategory => "Select Category";
  @override
  String get feedbackRequest => "Request";
  @override
  String get feedbackSuggestion => "Suggestion";
  @override
  String get feedbackComplaint => "Complaint";
  @override
  String get feedbackThankYou => "Thank You";
  @override
  String get feedbackOther => "Other";
  @override
  String get subjectTitle => "Subject Title";
  @override
  String get subjectHint => "Briefly state the subject of your feedback";
  @override
  String get maxCharacters100 => "Maximum 100 characters";
  @override
  String get yourMessage => "Your Message";
  @override
  String get messageHint => "You can write your detailed message here...";
  @override
  String get maxCharacters1000 => "Maximum 1000 characters";
  @override
  String get enterSubject => "Please enter a subject title";
  @override
  String get subjectTooShort => "Subject title is too short";
  @override
  String get enterMessage => "Please enter your message";
  @override
  String get messageTooShort => "Your message must be at least 10 characters";
  @override
  String get feedbackReceived => "Your Feedback Has Been Received";
  @override
  String get feedbackThanksRedirect => "Thank you for helping us improve our application. You will be redirected to the home page in 5 seconds.";
  @override
  String get returnNow => "Return Now";
  @override
  String get dropdownAccessibilityHint => "Double tap to see and change options";
  @override
  String get friendRequestsAndBlocks => "Friend Requests and Blocked List";
  @override
  String get incomingRequestsHeader => "Incoming Requests";
  @override
  String get noIncomingRequests => "No incoming requests.";
  @override
  String get outgoingRequestsHeader => "Outgoing Requests";
  @override
  String get noOutgoingRequests => "No outgoing requests.";
  @override
  String get blockedUsersHeader => "Blocked Users";
  @override
  String get noBlockedUsers => "No blocked users.";
  @override
  String get friendRequestAccepted => "Friend request accepted.";
  @override
  String get friendRequestRejected => "Friend request rejected.";
  @override
  String get userUnblocked => "User unblocked.";
  @override
  String get unnamed => "Unnamed";
  @override
  String get friendRequestFrom => "friend request from";
  @override
  String get friendRequestTo => "friend request sent to. Click to cancel.";
  @override
  String get cancelOutgoingRequest => "Cancel outgoing request";
  @override
  String get blockedUserInfo => "Blocked user. Click to unblock.";
  @override
  String get unblockUserTooltip => "Unblock user";
  @override
  String get messageNotifications => "Message Notifications";
  @override
  String get sound => "Sound";
  @override
  String get messageSoundSubtitle => "Play sound when a new message arrives";
  @override
  String get vibration => "Vibration";
  @override
  String get messageVibrationSubtitle => "Vibrate when a new message arrives";
  @override
  String get callNotifications => "Call Notifications";
  @override
  String get ringtone => "Ringtone";
  @override
  String get callSoundSubtitle => "Play ringtone for incoming calls";
  @override
  String get callVibrationSubtitle => "Vibrate for incoming calls";
  @override
  String get screenProtection => "Screen Recording Protection";
  @override
  String get screenProtectionSubtitle => "Prevents screenshots and recording inside the app";
  @override
  String get showOnLockScreen => "Show on Lock Screen";
  @override
  String get showOnLockScreenSubtitle => "Application remains visible even when the screen is locked";
  @override
  String get fullnamePrivacy => "Full Name Information";
  @override
  String get whoCanSeeThis => "Choose who can see this information";
  @override
  String get everyone => "Everyone";
  @override
  String get friends => "Friends";
  @override
  String get nobody => "Nobody";
  @override
  String get fullnamePrivacySemantics => "Full name privacy setting";
  @override
  String get lastSeen => "Last Seen Information";
  @override
  String get lastSeenSubtitle => "Allow other users to see your last seen time";
  @override
  String get birthday => "Birthday";
  @override
  String get birthdayPrivacySemantics => "Birthday privacy setting";
  @override
  String get privacyFooter => "Privacy settings ensure your application security and the protection of your personal data.";
  @override
  String get profileInfo => "Profile Information";
  @override
  String get profileLoadError => "Profile could not be loaded";
  @override
  String get removeFromFriends => "Remove from My Friend List";
  @override
  String get removedFromFriends => "Removed from friends.";
  @override
  String get blockUser => "Block User";
  @override
  String get userBlocked => "User blocked.";
  @override
  String get operationFailed => "Operation failed";
  @override
  String get userNotFound => "User not found.";
  @override
  String get unspecified => "Unspecified";
  @override
  String get hidden => "Hidden";
  @override
  String get lastSeenUnknown => "Last seen unknown";
  @override
  String get lastSeenHidden => "Last seen hidden";
  @override
  String get currentlyActive => "Currently active";
  @override
  String get lastSeenToday => "Last seen today";
  @override
  String get userProfilePhoto => "profile photo of";
  @override
  String get about => "About";
  @override
  String get details => "Details";
  @override
  String get joined => "Joined";
  @override
  String get addAsFriend => "Add as Friend";
  @override
  String get youAreFriends => "You are friends";
  @override
  String get friendRequestSent => "Friend Request Sent";
  @override
  String get wantsToAddYou => "Wants to add you";
  @override
  String get friendRequestSentSuccess => "Friend request sent!";
  @override
  String get noPermissionView => "You do not have permission to view this page.";
  @override
  String get latest => "Latest";
  @override
  String get taskOverview => "Task Overview and History";
  @override
  String get generalStats => "General Statistics";
  @override
  String get total => "Total";
  @override
  String get completed => "Completed";
  @override
  String get pending => "Pending";
  @override
  String get myPendingTasks => "My Pending Tasks";
  @override
  String get myCompletedTasks => "History (Completed) Tasks";
  @override
  String get noPendingTasksFound => "You have no pending tasks.";
  @override
  String get noCompletedTasksFound => "You have no completed tasks.";
  @override
  String taskOverviewAnnouncement(int total, int completed, int pending) => 
    "Task Overview and History page. In total $total tasks, $completed completed, $pending pending tasks found.";
  @override
  String taskOverviewStatsLabel(int total, int completed, int pending) => 
    "General Statistics. In total $total tasks, $completed completed and $pending pending tasks found";

  @override
  String get taskOverview => "Task Overview and History";
  @override
  String get generalStats => "General Statistics";
  @override
  String get total => "Total";
  @override
  String get completed => "Completed";
  @override
  String get pending => "Pending";
  @override
  String get myPendingTasks => "My Pending Tasks";
  @override
  String get myCompletedTasks => "My Background (Completed) Tasks";
  @override
  String get noPendingTasksFound => "No pending tasks found.";
  @override
  String get noCompletedTasksFound => "No completed tasks found.";
  @override
  String taskOverviewAnnouncement(int total, int completed, int pending) => 
    "Task Overview and History page. In total of $total tasks, there are $completed completed and $pending pending tasks.";
  @override
  String taskOverviewStatsLabel(int total, int completed, int pending) => 
    "General Statistics. In total of $total tasks, there are $completed completed and $pending pending tasks";
  @override
  String get inFavorites => "In favorites.";
  @override
  String get notInFavorites => "Not in favorites.";
  @override
  String boardAnnouncement(String name, String favText, int listCount, bool isOwner) {
    String prefix = isOwner ? "" : "Shared with you ";
    return "${prefix}board named $name, $favText There are $listCount lists inside. Double tap to enter the board, long press to change favorite status.";
  }
  @override
  String boardDetailAnnouncement(String name) => "You are inside the board named $name.";
  @override
  String get boardOptionsHint => "Double tap with two fingers or long press to see board options.";
  @override
  String get dropdownHint => "Double tap to see and change options";
  @override
  String get dropdownAccessibilityHint => "Double tap to see and change options";
  @override
  String get lastSeenHidden => "Last seen hidden";
  @override
  String get activeNow => "Active now";
  @override
  String get lastSeenToday => "Last seen today";
  @override
  String get statusFailed => "Failed to get status";
  @override
  String get gameInviteTitle => "Game Request";
  @override
  String get gameInviteDesc => "sent you a game invite for a quiz.";
  @override
  String get accept => "Accept";
  @override
  String get reject => "Reject";
  @override
  String get exitAppTitle => "Exit App";
  @override
  String get exitAppConfirm => "Are you sure you want to exit the app?";
  @override
  String get exit => "EXIT";
  @override
  String get newChatTooltip => "Start New Chat";
  @override
  String get newServerTooltip => "Create New Chat Server";
  @override
  String get createServerTitle => "New Chat Server";
  @override
  String get serverNameLabel => "Server Name";
  @override
  String get serverNameHint => "Ex: Blind Social Friends";
  @override
  String get serverNameRequired => "Server name cannot be empty";
  @override
  String get serverNameTooShort => "Server name cannot be shorter than 3 characters";
  @override
  String get capacityLabel => "Person Capacity";
  @override
  String get securitySettings => "Security Settings";
  @override
  String get serverPasswordLabel => "Server Password (Numeric)";
  @override
  String get serverPasswordHint => "Leave empty for no password";
  @override
  String get create => "Create";
  @override
  String get serverCreatedSuccess => "Server created successfully!";
  @override
  String get serverNameMinLength => "Server name must be at least 3 characters.";
  @override
  String get serverLimitReached => "User can create at most 3 servers";
  @override
  String get serverLimitDaily => "You can create at most 2 servers per day";
  @override
  String get serverCreateGenericError => "Failed to create server. Please try again.";
  @override
  String get emptyChatList => "You don't have any chats yet.\nStart a new one.";
  @override
  String get unnamedChat => "Unnamed Chat";
  @override
  String get liveVoiceRoom => "Live Voice Room";
  @override
  String get reply => "Reply";
  @override
  String get microphoneAccessDenied => "Microphone access denied, joined as listener only.";
  @override
  String get connectionErrorWithStatus => "Connection error: ";
  @override
  String get speakerSet => "Speaker";
  @override
  String get earpieceSet => "Earpiece";
  @override
  String get headsetOrBluetoothSet => "Headset / Bluetooth";
  @override
  String get deleteMessage => "Delete";
  @override
  String get editMessage => "Edit";
  @override
  String get editMessageTitle => "Edit Message";
  @override
  String get editMessageHint => "Edit your message...";
  @override
  String get messageSentStatus => "Message sent";
  @override
  String get voiceSentStatus => "Voice message sent";
  @override
  String get messageDeletedStatus => "Message deleted from you.";
  @override
  String get favAddedStatus => "Message added to favorites.";
  @override
  String get favRemovedStatus => "Message removed from favorites.";
  @override
  String get addToFavs => "Add to Favorites";
  @override
  String get removeFromFavs => "Remove from Favorites";
  @override
  String get chatPinnedStatus => "Chat pinned";
  @override
  String get chatUnpinnedStatus => "Chat unpinned";
  @override
  String get chatArchivedStatus => "Chat archived";
  @override
  String get chatUnarchivedStatus => "Chat unarchived";
  @override
  String get voiceCall => "Voice Call";
  @override
  String get videoCall => "Video Call";
  @override
  String get missedCall => "Missed Call";
  @override
  String get group => "Group";
  @override
  String get privateChat => "Private Chat";
  @override
  String get servers => "Servers";
  @override
  String get admin => "Admin";
  @override
  String get failedToLoadDetails => "Failed to load details";
  @override
  String get favoriteMessages => "Favorite Messages";
  @override
  String get noMessagesYet => "No messages yet.";
  @override
  String get unreadMessageSuffix => "Unread Message";
  @override
  String get outgoingVideoCall => "Outgoing Video Call";
  @override
  String get outgoingVoiceCall => "Outgoing Voice Call";
  @override
  String get incomingVideoCall => "Incoming Video Call";
  @override
  String get incomingVoiceCall => "Incoming Voice Call";
  @override
  String get callAcceptedByYou => "You accepted the call";
  @override
  String get callAccepted => "Call accepted";
  @override
  String get outgoingCallUnanswered => "Outgoing call unanswered";
  @override
  String get missedVideoCall => "Missed Video Call";
  @override
  String get lineBusy => "Line Busy";
  @override
  String get callRejectedByYou => "You rejected the call";
  @override
  String get callRejected => "Call rejected";
  @override
  String get callCancelledByYou => "You cancelled the call";
  @override
  String get callCancelled => "Call cancelled";
  @override
  String get duration => "Duration";
  @override
  String get starred => "Starred";
  @override
  String get repliedMessage => "Replied message";
  @override
  String get yourVoiceMessage => "Your voice message";
  @override
  String get incomingVoiceMessage => "Incoming voice message";
  @override
  String get yourMessage => "Your message";
  @override
  String get incomingMessage => "Incoming message";
  @override
  String get edited => "Edited";
  @override
  String get voiceMessage => "Voice Message";
  @override
  String get currentlySpeaking => "Currently speaking";
  @override
  String get callLog => "Call Log";
  @override
  String get you => "You";
  @override
  String get replied => "Replied";
  @override
  String get typeMessage => "Type a message...";
  @override
  String get replyingTo => "Replying to";
  @override
  String get onlyAdminCanSendMessages => "Only Blind Social Team can send messages";
  @override
  String get user => "User";
  @override
  String unreadMessagesCount(int count) => "$count Unread Messages";
  @override
  String statusLastSeen(String date) => "Last seen $date";
  @override
  String statusTodayAt(String time) => "Last seen today $time";
  @override
  String voiceRoomCapacity(int count) => "$count Persons";
  @override
  String get deleteComment => "Delete Message";
  @override
  String get deleteCommentConfirm => "Are you sure you want to delete this message?";
  @override
  String get commentDeleted => "Message deleted";
  @override
  String get commentSent => "Message sent";
  @override
  String get sendingVoiceComment => "Sending voice message, please wait";
  @override
  String get voiceCommentSent => "Voice message sent successfully";
  @override
  String get noComments => "No messages yet. Be the first to send one.";

  @override
  String get connectionError => "Connection error occurred";
  @override
  String get genericError => "Something went wrong";
  @override
  String get accessDenied => "Access Denied";
}
