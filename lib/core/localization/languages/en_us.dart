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

  // Login/Auth
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
  String get continueWithGoogle => "Continue with Google";
  @override
  String get orWithEmail => "or with email";
  @override
  String get pleaseEnterEmailAndPassword => "Please enter your email and password.";
  @override
  String get authHint => "Continue. It will log in if registered, otherwise creates a new account.";
  @override
  String get noAccountAutoCreate => "If you don't have an account, it will be created automatically.";
  @override
  String get continueBtn => "Continue";
  @override
  String get passwordHint => "At least 8 characters";
  @override
  String get emailHint => "example@email.com";
  @override
  String get googleLoginSuccess => "Google login successful!";
  @override
  String get loginError => "Login failed.";
  @override
  String get registerError => "An error occurred during registration.";
  @override
  String get googleLoginCancel => "Google login cancelled.";
  @override
  String get invalidEmail => "Please enter a valid email address.";
  @override
  String get passwordTooShort => "Password must be at least 8 characters.";
  @override
  String welcomeScreenSemantics(String appName) => "Welcome to $appName. Please choose a login method.";
  @override
  String get googleLoginSemantics => "Sign in or sign up quickly with your Google account.";

  // Profile
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

  // Settings
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

  // Chat
  @override
  String get chats => "Chats";
  @override
  String get messagePlaceholder => "Type a message...";
  @override
  String get send => "Send";
  @override
  String get voiceMessage => "Voice Message";
  @override
  String get participants => "Participants";

  // Chat Input
  @override
  String get cancelRecording => "Cancel recording";
  @override
  String pausedRecording(String duration) => "Paused: $duration";
  @override
  String recording(String duration) => "Recording: $duration";
  @override
  String get resumeRecording => "Resume recording";
  @override
  String get pauseRecording => "Pause recording";
  @override
  String get toggleEmojiKeyboard => "Open/Close emoji keyboard";
  @override
  String get completeAndSend => "Complete and send recording";
  @override
  String get recordVoiceMessage => "Record voice message";
  @override
  String get sendMessage => "Send message";

  // Task Board
  @override
  String get taskBoard => "Task Board";
  @override
  String get myBoards => "My Boards";
  @override
  String get myTasks => "My Tasks";
  @override
  String get addBoard => "Add Board";
  @override
  String get addList => "Add List";
  @override
  String get addCard => "Add Card";
  @override
  String get createBoard => "Create Board";
  @override
  String get boardName => "Board Name";
  @override
  String get boardStats => "Board Statistics";
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
  String get editDescription => "Edit Description";
  @override
  String get noDescription => "No description added yet.";
  @override
  String get addChecklistItem => "Add checklist item";
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
  String get currentlyActive => "Currently active";
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
  String get taskOverview => "Task Overview";
  @override
  String get total => "Total";
  @override
  String get myPendingTasks => "My Pending Tasks";
  @override
  String get myCompletedTasks => "My Completed Tasks";
  @override
  String get noPendingTasksFound => "No pending tasks found";
  @override
  String get noCompletedTasksFound => "No completed tasks found";
  @override
  String taskOverviewAnnouncement(int total, int completed, int pending) => "You have $total tasks in total, $completed completed and $pending still pending.";
  @override
  String taskOverviewStatsLabel(int total, int completed, int pending) => "Total: $total, Completed: $completed, Pending: $pending";
  @override
  String get notInFavorites => "Not in Favorites";
  @override
  String boardAnnouncement(String name, String favText, int listCount, bool isOwner) => "Board named $name, list count $listCount, $favText";
  @override
  String boardDetailAnnouncement(String name) => "Board detail page for $name";
  @override
  String get boardOptionsHint => "Double tap or long press to see options";
  @override
  String get dropdownHint => "Select an option";
  @override
  String get activeNow => "Active Now";
  @override
  String get statusFailed => "Status Failed";
  @override
  String get accept => "Accept";
  @override
  String get reject => "Reject";
  @override
  String get exitAppTitle => "Exit Application";
  @override
  String get exitAppConfirm => "Are you sure you want to exit the application?";
  @override
  String get exit => "Exit";
  @override
  String get newChatTooltip => "New Chat";
  @override
  String get newServerTooltip => "New Server";
  @override
  String get serverNameLabel => "Server Name";
  @override
  String get serverNameHint => "Enter server name";
  @override
  String get serverNameRequired => "Server name is required";
  @override
  String get serverNameTooShort => "Server name is too short";
  @override
  String get serverPasswordLabel => "Server Password";
  @override
  String get serverPasswordHint => "Enter password";
  @override
  String get serverCreatedSuccess => "Server created successfully";
  @override
  String get serverNameMinLength => "Server name must be at least 3 characters";
  @override
  String get serverLimitReached => "Server limit reached";
  @override
  String get serverLimitDaily => "Daily server limit reached";
  @override
  String get serverCreateGenericError => "Failed to create server";
  @override
  String get unnamedChat => "Unnamed Channel";
  @override
  String get reply => "Reply";
  @override
  String get speakerSet => "Speaker set";
  @override
  String get voiceSentStatus => "Voice Sent";
  @override
  String get addToFavs => "Add to Favorites";
  @override
  String get removeFromFavs => "Remove from Favorites";
  @override
  String get voiceCall => "Voice Call";
  @override
  String get videoCall => "Video Call";
  @override
  String get privateChat => "Private Chat";
  @override
  String get servers => "Servers";
  @override
  String get noMessagesYet => "No messages yet";
  @override
  String get unreadMessageSuffix => "unread messages";
  @override
  String get outgoingCallUnanswered => "Unanswered outgoing call";
  @override
  String get callAccepted => "Call Accepted";
  @override
  String get callAcceptedByYou => "Call Accepted by You";
  @override
  String get callRejected => "Call Rejected";
  @override
  String get callRejectedByYou => "Call Rejected by You";
  @override
  String get callCancelled => "Call Cancelled";
  @override
  String get callCancelledByYou => "Call Cancelled by You";
  @override
  String get starred => "Starred";
  @override
  String get repliedMessage => "Replied Message";
  @override
  String get yourVoiceMessage => "Your Voice Message";

  // Campaigns
  @override
  String get campaigns => "Campaigns";
  @override
  String get categories => "Categories";
  @override
  String get all => "All";
  @override
  String get searchCampaign => "Search Campaign";
  @override
  String get noCampaignFound => "No campaign found";
  @override
  String get viewOnWeb => "View on Web";
  @override
  String get shareCampaign => "Share Campaign";
  @override
  String get inspectingCategory => "Inspecting category";
  @override
  String get campaignParticipation => "Participation";
  @override
  String get earningsUsage => "Earnings Usage";
  @override
  String get includedBrands => "Included Brands";
  @override
  String get otherCampaignsForBrand => "Other Campaigns for Brand";
  @override
  String get showLess => "Show Less";
  @override
  String get showAll => "Show All";
  @override
  String get campaignConditions => "Conditions";
  @override
  String get startDate => "Start Date";
  @override
  String get endDate => "End Date";

  // Errors
  @override
  String get connectionError => "Connection error occurred";
  @override
  String get genericError => "Something went wrong";
  @override
  String get accessDenied => "Access Denied";

  @override
  String get admin => "Admin";
  @override
  String get capacityLabel => "Capacity";
  @override
  String get chatArchivedStatus => "Archived";
  @override
  String get chatPinnedStatus => "Pinned";
  @override
  String get chatUnarchivedStatus => "Unarchived";
  @override
  String get chatUnpinnedStatus => "Unpinned";
  @override
  String get connectionErrorWithStatus => "Connection Error: ";
  @override
  String get create => "Create";
  @override
  String get createServerTitle => "Create Server";
  @override
  String get deleteMessage => "Delete Message";
  @override
  String get duration => "Duration";
  @override
  String get earpieceSet => "Earpiece mode active";
  @override
  String get editMessage => "Edit Message";
  @override
  String get editMessageHint => "Type your message...";
  @override
  String get editMessageTitle => "Edit Message";
  @override
  String get edited => "Edited";
  @override
  String get emptyChatList => "No chats found";
  @override
  String get failedToLoadDetails => "Failed to load details";
  @override
  String get favAddedStatus => "Added to favorites";
  @override
  String get favRemovedStatus => "Removed from favorites";
  @override
  String get favoriteMessages => "Favorite Messages";
  @override
  String get archivedChats => "Archived Chats";
  @override
  String get gameInviteDesc => "I've invited you to play a game!";
  @override
  String get gameInviteTitle => "Game Invite";
  @override
  String get generalStats => "General Stats";
  @override
  String get group => "Group";
  @override
  String get headsetOrBluetoothSet => "Headset/Bluetooth connected";
  @override
  String get inFavorites => "In Favorites";
  @override
  String get incomingVideoCall => "Incoming video call";
  @override
  String get incomingVoiceCall => "Incoming voice call";
  @override
  String get incomingVoiceMessage => "Incoming voice message";
  @override
  String get lineBusy => "Line busy";
  @override
  String get liveVoiceRoom => "Live Voice Room";
  @override
  String get messageDeletedStatus => "Message deleted";
  @override
  String get messageSentStatus => "Message sent";
  @override
  String get microphoneAccessDenied => "Microphone access denied";
  @override
  String get missedCall => "Missed call";
  @override
  String get missedVideoCall => "Missed video call";
  @override
  String get outgoingVideoCall => "Outgoing video call";
  @override
  String get outgoingVoiceCall => "Outgoing voice call";
  @override
  String get securitySettings => "Security Settings";
  @override
  String get blog => "Blog";
  @override
  String voiceRoomCapacity(String value) => "Capacity: $value";
  @override
  String get lastSeenHidden => "Last seen hidden";
  @override
  String get lastSeenToday => "Last seen today at";
  @override
  String get no => "No";
  @override
  String get yes => "Yes";
  @override
  String get typeMessage => "Type your message...";
  @override
  String get you => "You";
  @override
  String get replied => "Replied";
  @override
  String get replyingTo => "Replying to";
  @override
  String get callLog => "Call Log";
  @override
  String get sendFeedback => "Send Feedback";
  @override
  String get emptyTemplate => "Empty Template";
  @override
  String get softwareDevTemplate => "Software Development";
  @override
  String get dailyTasksTemplate => "Daily Tasks";
  @override
  String get projectMgmtTemplate => "Project Management";
  @override
  String get openBoard => "Open Board";
  @override
  String get currentlySpeaking => "currently speaking";
  @override
  String get deleteListSuccess => "list deleted";
  @override
  String get tasks => "tasks";
  @override
  String get options => "Options";
  @override
  String get task => "Task";
  @override
  String get january => "January";
  @override
  String get february => "February";
  @override
  String get march => "March";
  @override
  String get april => "April";
  @override
  String get may => "May";
  @override
  String get june => "June";
  @override
  String get july => "July";
  @override
  String get august => "August";
  @override
  String get september => "September";
  @override
  String get october => "October";
  @override
  String get november => "November";
  @override
  String get december => "December";
  @override
  String get permission => "Permission";
  @override
  String get add => "Add";
  @override
  String get edit => "Edit";
  @override
  String get editUppercase => "EDIT";
  @override
  String get delete => "Delete";
  @override
  String get label => "Label";
  @override
  String get statusUpdated => "Status updated";
  @override
  String get checklistTitle => "Checklist";
  @override
  String get copy => "Copy";
  @override
  String get deleteComment => "Delete Comment";
  @override
  String get editPost => "Edit Post";
  @override
  String get deletePost => "Delete Post";
  @override
  String get unlikePost => "Unlike Post";
  @override
  String get likePost => "Like Post";
  @override
  String get openComments => "Open Comments";
  @override
  String get deleteVoiceNote => "Delete Voice Note";
  @override
  String get playRecording => "Play Recording";
  @override
  String get deleteRoom => "Delete Room";
  @override
  String get kickUser => "Kick User";
  @override
  String get banUser => "Ban User";
  @override
  String get unbanUser => "Unban User";
  @override
  String get playRecordAnnounce => "Playing recording";
  @override
  String get deleteCommentConfirm => "Are you sure you want to delete this comment?";
  @override
  String get commentDeleted => "Comment deleted";
  @override
  String get commentSent => "Comment sent";
  @override
  String get sendingVoiceComment => "Sending voice comment...";
  @override
  String get voiceCommentSent => "Voice comment sent";
  @override
  String get noComments => "No comments yet.";
  @override
  String get writeComment => "Write a comment...";
  @override
  String get close => "Close";
  @override
  String get sendComment => "Send Comment";
  @override
  String get fetchingCommentsError => "Error fetching comments";
  @override
  String get failedToPostComment => "Failed to post comment";
  @override
  String commentUserAvatarSemantics(String username) => "$username's profile";
  @override
  String get viewProfileDetailsHint => "View profile details";
  @override
  String messageSemanticLabel({
    required bool isFavorite,
    required bool isVoice,
    required bool isMyMessage,
    required bool isCall,
    required bool isEdited,
    required String content,
    required String time,
    required String reactions,
  }) {
    String label = isFavorite ? 'Starred. ' : '';
    if (isVoice) {
      label += isMyMessage ? "Voice message you sent. $time" : "Incoming voice message. $time";
    } else if (isCall) {
      label += "$content. $time";
    } else {
      label += isMyMessage ? "Message you sent: $content. $time" : "Incoming message: $content. $time";
    }
    if (isEdited) label += '. Edited';
    if (reactions.isNotEmpty) label += '. Reactions: $reactions';
    return label;
  }
  @override
  String get messageLongPressHint => "Long press for reactions or other options";
  @override
  String get myPostsPage => "My posts page";
  @override
  String get myPostsPageHint => "Double tap to see all your shared posts";
  @override
  String get shareNewPost => "Share new post";
  @override
  String blogPostSemanticLabel({
    required String username,
    required String time,
    required String content,
    required int likes,
    required int comments,
  }) => "$username. $time. $content. $likes likes, $comments comments.";
  @override
  String get closeBottomSheet => "Close";
  @override
  String get speaker => "Speaker";
  @override
  String get video => "Video";
  @override
  String get mute => "Mute";
  @override
  String get share => "Share";
  @override
  String get switchCamera => "Switch Camera";
  @override
  String get endCall => "End Call";
  @override
  String get answer => "Answer";
  @override
  String get decline => "Decline";
  @override
  String get recordingProgress => "Recording progress";
  @override
  String get rewind5s => "Rewind 5 seconds";
  @override
  String get forward5s => "Forward 5 seconds";
  @override
  String recordingDurationLabel(String position, String duration) => "Recording progress: $position / $duration";
  @override
  String get stopVoiceMessage => "Stop Voice Message";
  @override
  String get playVoiceMessage => "Play Voice Message";
  @override
  String get incomplete => "Incomplete";
  @override
  String statusTodayAt(String time) => "Today at $time";
  @override
  String statusLastSeen(String date) => "Last seen: $date";
  @override
  String get user => "User";
  @override
  String unreadMessagesCount(int count) => "$count unread messages";
  @override
  String get versionLabel => "Version";
  @override
  String version(String value) => "Version $value";
  @override
  String get radioSearchHint => "Search Channel...";
  @override
  String get radioRecordings => "Recordings";
  @override
  String get radioFavorites => "Favorites";
  @override
  String get radioAllChannels => "All Channels";
  @override
  String get radioOnAir => "ON AIR";
  @override
  String get radioStopped => "STOPPED";
  @override
  String get radioStartRecording => "Start Recording";
  @override
  String get radioStopRecording => "Stop Recording";
  @override
  String radioVolumeLevel(int level) => "Volume Level: $level%";
  @override
  String get radioSleepTimerTitle => "Sleep Timer";
  @override
  String get radioPreviousChannel => "Previous Channel";
  @override
  String get radioNextChannel => "Next Channel";
  @override
  String get radioPlay => "Start Broadcast";
  @override
  String get radioPause => "Stop Broadcast";
  @override
  String get radioRecordingStopHint => "Double tap to stop recording";
  @override
  String get radioRecordingStartHint => "Double tap to record live broadcast";
  @override
  String radioSleepMode(String time) => "Sleep Mode: $time";
  @override
  String radioFavAdded(String name) => "$name added to favorites.";
  @override
  String radioFavRemoved(String name) => "$name removed from favorites.";
  @override
  String playbackError(String error) => "Playback error: $error";
  @override
  String get invalidFileFormat => "Invalid file format or content. Please verify the recording.";
  @override
  String radioRecordingShareText(String name) => "$name radio recording";
  @override
  String get fileNotFound => "File not found";
  @override
  String recordingSemanticLabel(String station, String date, String time, String duration) => "$station. Recorded on $date at $time. Duration $duration.";
  @override
  String get durationLabel => "Duration";
  @override
  String get failedToDeletePost => "Post could not be deleted";
  @override
  String get failedToUpdatePost => "Post could not be updated";
  @override
  String get likeProcessFailed => "Like operation failed";
  @override
  String get globalErrorOccurred => "A global error occurred in the application";
  @override
  String get exitAndClose => "LOGOUT AND CLOSE";
  @override
  String unreadMessagesSuffix(int count) => "You have $count unread new messages.";
  @override
  String lastMessagePrefix(String content) => "Last message: $content.";
  @override
  String get platformActionHintWeb => "Long press for action menu.";
  @override
  String get platformActionHintMobile => "Swipe up or down for action options.";
  @override
  String get showOptions => "Show Options";
  @override
  String get tapToGoToChat => "Tap to go to chat";
  @override
  String get doubleTapToOpenChat => "Double tap to open chat";
  @override
  String get deleteChatTitle => "Delete Chat";
  @override
  String get deleteChatConfirm => "Are you sure you want to delete this chat? This action cannot be undone.";
  @override
  String get chatDeletedStatus => "Chat deleted.";
  @override
  String chatDeleteError(String error) => "Could not delete chat: $error";
  @override
  String get incomingMessage => "Incoming message";
  @override
  String get onlyAdminCanSendMessages => "Only admins can send messages";
  @override
  String get noVoiceNotesAdded => "No voice notes added.";
  @override
  String get recordNewVoiceNote => "Record New Voice Note (Max 5 mins)";
  @override
  String get voiceNote => "Voice Note";
  @override
  String get deleteThisVoiceNote => "Delete this voice note";
  @override
  String get voiceRecorderInitError => "Voice recorder could not be initialized: ";
  @override
  String get voiceNoteSavedSuccessfully => "Voice note saved successfully.";
  @override
  String get voiceNoteUploadError => "Voice note could not be uploaded: ";
  @override
  String get voiceNoteDeleted => "Voice note deleted.";
  @override
  String get voiceNoteDeleteError => "Voice note could not be deleted: ";
  @override
  String get voiceNotePlayError => "Voice note could not be played: ";

  @override
  String get taskStopwatch => "Task Stopwatch";
  @override
  String get stopStopwatch => "Stop Stopwatch";
  @override
  String get startStopwatch => "Start Stopwatch";
  @override
  String get startNewStopwatch => "Start New Stopwatch";
  @override
  String get stopwatchStarted => "Stopwatch started.";
  @override
  String get stopwatchStopped => "Stopwatch stopped.";

  @override
  String get socialSection => "Social";
  @override
  String get friendAndBlockedList => "Friends & Blocked List";
  @override
  String get gamesArea => "Games Area";
  @override
  String get contentAndToolsSection => "Content & Tools";
  @override
  String get liveRadio => "Live Radio";
  @override
  String get tools => "Tools";
  @override
  String get systemSection => "System";
  @override
  String get administrationSection => "Administration";
  @override
  String get adminPanel => "Admin Panel";
  @override
  String get developerModeLogs => "Developer Mode / Logs";

  // Semantics & Actions
  @override
  String get viewProfile => "View Profile";
  @override
  String get unarchiveChat => "Unarchive";
  @override
  String get archiveChat => "Archive";
  @override
  String get unpinChat => "Unpin";
  @override
  String get pinChat => "Pin";
  @override
  String get deleteChat => "Delete Chat";
  @override
  String get kickFromServer => "Kick from Server";
  @override
  String serverSemanticLabel(String serverName, String description, String capacity, String encryptedText, String onlineCount) =>
      "Server name $serverName. Description $description. $capacity capacity $encryptedText server. Currently $onlineCount people are online.";
  @override
  String get joinServerHint => "Double tap to join the server";
  @override
  String joinedServerAnnounce(String serverName) => "You are now connected to the server named $serverName.";
  @override
  String get doubleTapToSeeOptionsHint => "Double tap to see and change options";
  @override
  String roomCreatedAnnounce(String roomName) => "Room named $roomName has been successfully created.";
  @override
  String roomSemanticLabel(String roomName, String roomType) => "$roomType room named $roomName";
  @override
  String get joinRoomHint => "Double tap to enter the room";
  @override
  String get roomsTabCreatorHint => "Rooms tab. To delete rooms, you can use the delete room option from the actions menu while on the relevant room (by swiping up and down with one finger).";
  @override
  String get roomsTabHint => "Rooms tab";
  @override
  String get messageReactionSemantic => "Leave a reaction to message";
  @override
  String get shareRecording => "Share Recording";
  @override
  String get removeRecording => "Delete Recording";
  @override
  String get deleteLog => "Delete Work Log";

  // Additional found items
  @override
  String errorLabel(String errorMsg) => "Error: $errorMsg";
  @override
  String get workHistory => "Work History";
  @override
  String get lessThanOneMinute => "Less than 1 minute";
  @override
  String get daysSuffix => "days";
  @override
  String get hoursSuffix => "hours";
  @override
  String get minutesSuffix => "minutes";
  @override
  String get recordingStarted => "Recording started";
  @override
  String get recordingPaused => "Recording paused";
  @override
  String get recordingResumed => "Recording resumed";
  @override
  String get recordingCancelled => "Recording cancelled";
  @override
  String get recordingStopped => "Recording stopped";
  @override
  String get voiceNoteSaved => "Voice note saved successfully.";
  @override
  String get cancelBtn => "Cancel";
  @override
  String get finishBtn => "Finish";
  @override
  String playRadioError(String stationName) => "Failed to play $stationName. Connection error.";
  @override
  String get sleepTimerCancelled => "Sleep timer cancelled.";
  @override
  String get sleepTimerExpired => "Sleep timer expired. Broadcast stopped.";
  @override
  String sleepTimerSet(String minutes) => "Sleep timer set to $minutes minutes.";
  @override
  String get cancelTimerBtn => "Cancel Timer";
  @override
  String recordingCompleted(String stationName) => "Recording completed: $stationName";
  @override
  String get recordingStoppedAndSaved => "Recording stopped and saved";
  @override
  String get recordingInit => "Recording initializing...";
  @override
  String get liveRadioRecordingStarted => "Live radio recording started";
  @override
  String get savedRecordingsTitle => "Saved Broadcasts";
  @override
  String get noSavedRecordings => "No saved broadcasts yet.";
  @override
  String get permanentlyDeleteNotice => "Are you sure you want to permanently delete this recording from your phone?";
  @override
  String get cancelUppercase => "CANCEL";
  @override
  String get deleteUppercase => "DELETE";
  @override
  String get shareError => "Share error";
  @override
  String get deleteRecording => "Delete Recording";
  @override
  String get ongoingWork => "Ongoing work";
  @override
  String get completedWork => "Completed work";
  @override
  String get myPosts => "My Posts";
  @override
  String get deleteConfirmTitle => "Confirm Delete";
  @override
  String get deletePostConfirm => "Are you sure you want to delete this post?";
  @override
  String get postDeleted => "Post deleted.";
  @override
  String get editPostTitle => "Edit Post";
  @override
  String get postUpdated => "Post updated.";
  @override
  String get noPostsYet => "You haven't shared any posts yet.";

  // Blog
  @override
  String get myBlogPosts => "My Blog Posts";
  @override
  String get deletePostConfirmTitle => "Confirm Delete";
  @override
  String get deletePostConfirmMessage => "Are you sure you want to delete this post?";
  @override
  String get editPostDialogTitle => "Edit Post";
  @override
  String get editPostHint => "Edit your post here...";
  @override
  String get postCreated => "Post shared.";
  @override
  String get postCreationFailed => "Post could not be shared.";
  @override
  String get postDeleteFailed => "Post could not be deleted.";
  @override
  String get postUpdateFailed => "Post could not be updated.";
  @override
  String get createPostDialogTitle => "Create New Post";
  @override
  String get createPostHint => "What do you think?";
  @override
  String get onlyOwnerCanEdit => "Only the content owner can edit.";
  @override
  String get commentsHint => "Comments...";
  @override
  String get readCommentsHint => "Double tap to read and write comments";

  // Server Settings
  @override
  String get serverSettings => "Server Settings";
  @override
  String get general => "General";
  @override
  String get rooms => "Rooms";
  @override
  String get banned => "Banned";
  @override
  String get basicInfo => "Basic Information";
  @override
  String get serverName => "Server Name";
  @override
  String personCapacity(int value) => "$value People Capacity";
  @override
  String get securityAndPermissions => "Security and Permissions";
  @override
  String get membersCanCreateRooms => "Members Can Create Rooms";
  @override
  String get onlyCreatorCanCreateRooms => "Only creator can create rooms";
  @override
  String get serverPassword => "Server Password (Numeric Only)";
  @override
  String get deleteServer => "Delete Server";
  @override
  String get deleteServerConfirm => "Are you sure you want to delete the server? This action cannot be undone.";
  @override
  String get deleteServerWarning => "This action cannot be undone.";
  @override
  String get kickMember => "Kick Member";
  @override
  String kickMemberConfirm(String username) => "Should $username be kicked from this server?";
  @override
  String get kick => "Kick";
  @override
  String get banMember => "Ban Member";
  @override
  String banMemberConfirm(String username) => "Should $username be permanently banned from the server? They won't be able to log in again.";
  @override
  String get ban => "Ban";
  @override
  String get unbanMember => "Unban Member";
  @override
  String unbanMemberConfirm(String username) => "Should the ban of $username be lifted?";
  @override
  String get unban => "Unban";
  @override
  String get roomDeleted => "Room deleted.";
  @override
  String get memberKicked => "Member kicked.";
  @override
  String get memberBanned => "Member successfully banned.";
  @override
  String get unbanned => "Ban lifted.";
  @override
  String get roomNotFound => "Room not found.";
  @override
  String get memberNotFound => "Member not found.";
  @override
  String get noBannedMembers => "No banned members found.";
  @override
  String get removeMemberTooltip => "Remove from ban list";

  // Servers
  @override
  String get chatRooms => "Chat Rooms";
  @override
  String get noRoomsFound => "No rooms found.";
  @override
  String get descriptionNone => "No description";
  @override
  String get serverOwner => "Owner";
  @override
  String get serverAdmin => "Admin";
  @override
  String get serverMember => "Member";
  @override
  String get sunucuSahibiYasaklayabilir => "Only the server owner can perform banning.";
  @override
  String get sunucudanAt => "Kick from Server";
}
