# GamesBox — Improvement & Enhancement Planning

> **Scope**: `gamesbox_common` · `gamesbox_kids` · `gamesbox_parent`
> **Main priority**: Bug/missing files fixes → QR pairing → QR unlock → Firebase sync & security → UX polish

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Analysis](#2-problem-analysis)
   - 2.1 [Missing / Broken — Must Be Fixed](#21-missing--broken--must-be-fixed)
   - 2.2 [Code Duplication](#22-code-duplication)
   - 2.3 [Security Vulnerabilities](#23-security-vulnerabilities)
3. [New Feature: QR Code Pairing & Unlock](#3-new-feature-qr-code-pairing--unlock)
   - 3.1 [Initial QR Pairing Flow](#31-initial-qr-pairing-flow)
   - 3.2 [QR Unlock Flow (Extra Time)](#32-qr-unlock-flow-extra-time)
   - 3.3 [Required Packages](#33-required-packages)
4. [UX Improvements — Kids App](#4-ux-improvements--kids-app)
5. [UX Improvements — Parent App](#5-ux-improvements--parent-app)
6. [Architecture Improvements](#6-architecture-improvements)
7. [Firebase Security Rules](#7-firebase-security-rules)
8. [New & Modified Files Plan](#8-new--modified-files-plan)
9. [Implementation Phases](#9-implementation-phases)
10. [Additional Technical Notes](#10-additional-technical-notes)

---

## 1. Executive Summary

The GamesBox application consists of three Flutter modules: `gamesbox_common` (shared library), `gamesbox_kids` (child device), and `gamesbox_parent` (parent device). After a thorough code review, the following was found:

- **6 bugs/missing methods** causing compile errors or runtime errors
- **4 duplicated screens/widgets** exactly the same between the two apps
- **QR pairing feature not yet implemented** (only placeholder)
- **QR unlock feature completely missing** — parents can only reset via local storage
- **Firebase database is wide open** (no rules)
- **Sensitive credentials** (OTP secret, PIN) stored in plain text in SharedPreferences

Fixes are grouped into **5 phases** with a total estimate of ~12 working days.

---

## 2. Problem Analysis

### 2.1 Missing / Broken — Must Be Fixed

#### BUG-01 · `FirebaseService.getCurrentUser()` is undefined

- **Problematic file**: `gamesbox_parent/lib/screens/child_management_screen.dart` line ~37
- **Issue**: Calls `FirebaseService.getCurrentUser()` which does not exist in `firebase_service.dart`
- **Solution**: Add the following method to `gamesbox_common/lib/services/firebase_service.dart`:

```dart
static User? getCurrentUser() => FirebaseAuth.instance.currentUser;
```

---

#### BUG-02 · `TimeLimitService` — inconsistency between static and instance

- **Problematic files**:
  - `gamesbox_parent/lib/screens/time_limit_screen.dart` → calls `_service.setDailyLimit(tl)` (instance)
  - `gamesbox_parent/lib/widgets/child_time_limit_card.dart` → calls `TimeLimitService.setLimitMinutes(...)` (static)
- **Issue**: `time_limit_screen.dart` instantiates `TimeLimitService()` but all methods are already `static`
- **Solution**: Remove instantiation in `time_limit_screen.dart`, replace with:

```dart
// Before
final TimeLimitService _service = TimeLimitService();
await _service.setDailyLimit(tl);

// After
await TimeLimitService.setDailyLimit(tl);
```

---

#### BUG-03 · Kids app always starts from `PairingScreen`

- **Problematic file**: `gamesbox_kids/lib/main.dart`
- **Issue**: `home` is always `PairingScreen` — child must re-pair every time the app opens
- **Solution**: Replace startup logic using `SplashScreen` that checks `StorageService`:

```dart
// gamesbox_kids/lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.init();
  runApp(const KidsApp());
}

class KidsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const KidsSplashScreen(), // NEW
      routes: {
        '/pairing': (context) => const PairingScreen(),
        '/home':    (context) => const HomeScreen(),
        '/games':   (context) => const GamesListScreen(),
      },
    );
  }
}
```

```dart
// KidsSplashScreen — check pairing status
Future.delayed(const Duration(seconds: 2), () async {
  final kidId = await StorageService.getFamilyId(); // reuse key or create _keyKidId
  Navigator.pushReplacementNamed(
    context,
    kidId != null ? '/home' : '/pairing',
  );
});
```

---

#### BUG-04 · `gamesbox_kids` has no sync service to Firebase

- **Issue**: Kids app only stores `playedTodaySeconds` in local SharedPreferences. Parent app reads from `kids/{kidId}/playedTodaySeconds` in Firebase — data is never synchronized
- **Solution**: Create `KidSyncService` (see [section 8](#8-new--modified-files-plan))

---

#### BUG-05 · `OtpService.generateSecret()` — weak randomness

- **Problematic file**: `gamesbox_parent/lib/services/otp_service.dart` line ~121
- **Issue**: Uses `DateTime.now().millisecondsSinceEpoch` as seed — predictable
- **Solution**: Use `dart:math Random.secure()`:

```dart
import 'dart:math';

static String generateSecret() {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  final rng = Random.secure();
  final buffer = List<int>.generate(16, (_) => rng.nextInt(256));
  return _base32Encode(buffer);
}
```

---

#### BUG-06 · `PairingService` — pairing code is too short

- **Problematic file**: `gamesbox_parent/lib/services/pairing_service.dart`
- **Issue**: Generates 6-digit numeric (`100000–999999`) → only 900,000 combinations, easy to brute-force
- **Solution**: Use 8-character alphanumeric format or use `family_id` (Firebase push key) directly as the pairing code

---

### 2.2 Code Duplication

The following code exists exactly the same in both apps — must be moved to `gamesbox_common`:

| File | Kids Location | Parent Location | Action |
|---|---|---|---|
| `home_screen.dart` | `gamesbox_kids/lib/screens/` | `gamesbox_parent/lib/screens/` | Move to common or remove parent version |
| `parent_dashboard.dart` | `gamesbox_kids/lib/screens/` | `gamesbox_parent/lib/screens/` | Move to common |
| `register_screen.dart` | `gamesbox_kids/lib/screens/` | `gamesbox_parent/lib/screens/` | Separate logic, shared UI to common |
| `password_dialog.dart` | `gamesbox_kids/lib/widgets/` | `gamesbox_parent/lib/widgets/` | Move to `gamesbox_common/lib/widgets/` |
| `section_card.dart` | `gamesbox_kids/lib/widgets/` | `gamesbox_parent/lib/widgets/` | Move to `gamesbox_common/lib/widgets/` |
| `timer_card.dart` | `gamesbox_kids/lib/widgets/` | `gamesbox_parent/lib/widgets/` | Move to `gamesbox_common/lib/widgets/` |
| `app_selection_screen.dart` | `gamesbox_kids/lib/screens/` | `gamesbox_parent/lib/screens/` | Move to common |

After moving, export in `gamesbox_common/lib/gamesbox_common.dart`:

```dart
// Widgets shared
export 'widgets/password_dialog.dart';
export 'widgets/section_card.dart';
export 'widgets/timer_card.dart';
// Screens shared
export 'screens/app_selection_screen.dart';
export 'screens/parent_dashboard.dart';
```

---

### 2.3 Security Vulnerabilities

| ID | Issue | Risk | Solution |
|---|---|---|---|
| SEC-01 | OTP secret stored in `SharedPreferences` plain text | Medium — can be read if device is rooted | Migrate to `flutter_secure_storage` |
| SEC-02 | Parent PIN stored in `SharedPreferences` plain text | Medium | Migrate to `flutter_secure_storage` |
| SEC-03 | No `database.rules.json` | High — anyone can read/write all data | Implement Firebase rules (see [section 7](#7-firebase-security-rules)) |
| SEC-04 | Weak randomness in `generateSecret()` | Medium | Use `Random.secure()` (already in BUG-05) |
| SEC-05 | QR unlock has no signature verification | High — child can forge payload | Implement HMAC-SHA256 in `QrUnlockService` |

---

## 3. New Feature: QR Code Pairing & Unlock

### 3.1 Initial QR Pairing Flow

```
[Parent App]                              [Kids App]
     │                                         │
     │  1. Register / Login                    │
     │  2. createFamily() → familyId           │
     │  3. Render QR (encode: familyId)        │
     │     ─────────────────────────────────▶  │
     │                                    4. Scan QR
     │                                    5. Decode familyId
     │                                    6. pairWithOtp(familyId)
     │                                    7. Firebase: kids.push({name, parentId})
     │                                    8. Save kidId locally
     │                                    9. Show HomeScreen
```

**QR payload format (pairing)**:

```json
{
  "type": "pair",
  "familyId": "<firebase_push_key>",
  "appVersion": "1"
}
```

Encode as JSON string → QR code. No encryption needed because `familyId` is a public key only useful once (after pairing succeeds, the code cannot be reused).

---

### 3.2 QR Unlock Flow (Extra Time)

```
[Kids App — Locked]                       [Parent App]
     │                                         │
     │  1. Time runs out → LockedScreen        │
     │  2. Tap "Ask parent's permission"       │
     │  3. Show QR scanner                     │
     │                                    4. Open ChildDetailScreen
     │                                    5. Tap "Give extra time"
     │                                    6. Select duration (15/30/60 min)
     │                                    7. QrUnlockService.generateUnlockQr()
     │                                    8. Render QR (payload + HMAC)
     │     ◀─────────────────────────────────  │
     │  9. Scan QR                             │
     │  10. QrUnlockService.verifyAndApply()   │
     │  11. Verify HMAC & expiry (5 min)     │
     │  12. Add minutes to daily limit       │
     │  13. Return to HomeScreen               │
```

**QR payload format (unlock)**:

```json
{
  "type": "unlock",
  "kidId": "<kid_firebase_key>",
  "extraMinutes": 30,
  "expiresAt": 1749123456789,
  "hmac": "<base64_hmac_sha256>"
}
```

**HMAC is computed from**: `kidId + extraMinutes + expiresAt` using the OTP secret as the key.

---

### 3.3 Required Packages

#### `gamesbox_parent/pubspec.yaml` — add:

```yaml
dependencies:
  qr_flutter: ^4.1.0          # already in pubspec, needs to be activated
  pretty_qr_code: ^3.3.0      # already exists, for nicer QR display
  flutter_secure_storage: ^9.0.0
  firebase_messaging: ^15.0.0  # push notifications
```

#### `gamesbox_kids/pubspec.yaml` — add:

```yaml
dependencies:
  mobile_scanner: ^6.0.0      # scan QR via camera
  flutter_secure_storage: ^9.0.0
```

#### `gamesbox_common/pubspec.yaml` — add:

```yaml
dependencies:
  crypto: ^3.0.3              # already in otp_service, ensure it's in common
  flutter_secure_storage: ^9.0.0
```

---

## 4. UX Improvements — Kids App

### UX-K-01 · Locked Screen — Full Screen

**Current issue**: When time runs out, only a regular `AlertDialog` is shown that can be dismissed.

**Solution**: Create `LockedScreen` as a full route that cannot be popped without QR unlock:

```
┌─────────────────────────────────┐
│                                 │
│       🎮 (Fun animation)        │
│                                 │
│   Your play time for today      │
│       has run out!              │
│                                 │
│   Take a break first, you can   │
│   play again tomorrow 😊        │
│                                 │
│  ┌─────────────────────────┐    │
│  │  📷  Ask parent's       │    │
│  │       permission        │    │
│  │       (scan QR)         │    │
│  └─────────────────────────┘    │
│                                 │
│   Time until reset: 08:23:14    │
│                                 │
└─────────────────────────────────┘
```

- Use `PopScope(canPop: false)` so the child cannot go back
- Show countdown until the next daily reset (midnight)
- "Ask permission" button opens QR scanner for unlock

---

### UX-K-02 · Greet Child by Real Name

**Issue**: Hardcoded `"Hello, Andi! 👋"` in `home_screen.dart` line ~183.

**Solution**:
1. When pairing succeeds, ask the child to enter their name (`TextInputDialog` after successful pairing)
2. Save to `StorageService` with a new key `_keyKidName`
3. Display on HomeScreen with an avatar initial circle

```dart
// StorageService — add
static const String _keyKidName = 'kid_name';
static Future<void> saveKidName(String name) async { ... }
static Future<String> getKidName() async { ... }
```

---

### UX-K-03 · Pairing Screen — Two Tabs (Scan QR + Manual Code)

**Solution**: Refactor `PairingScreen` into `TabBarView`:

- **Tab 1 — Scan QR**: Show `MobileScanner` widget, auto-process when QR is read
- **Tab 2 — Manual Code**: Text field for 6-digit OTP, auto-submit when 6 characters are filled

```dart
TabController _tabController = TabController(length: 2, vsync: this);

// Tab 1
MobileScanner(
  onDetect: (capture) {
    final code = capture.barcodes.first.rawValue;
    _handleQrCode(code);
  },
)

// Tab 2
TextField(
  maxLength: 6,
  keyboardType: TextInputType.number,
  onChanged: (v) { if (v.length == 6) _pairWithCode(v); },
)
```

---

### UX-K-04 · Sync Play Time to Firebase

**Issue**: `GameSessionScreen` only stores to local storage when the session ends. If the app is force-closed, data is lost.

**Solution**: `KidSyncService` — push to Firebase every 30 seconds while the session is running:

```dart
class KidSyncService {
  static Timer? _syncTimer;

  static void startPeriodicSync(String kidId) {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pushPlayedSeconds(kidId);
    });
  }

  static Future<void> _pushPlayedSeconds(String kidId) async {
    final seconds = await StorageService.getTotalPlayed();
    await FirebaseDatabase.instance
        .ref('kids/$kidId/playedTodaySeconds')
        .set(seconds);
    await FirebaseDatabase.instance
        .ref('kids/$kidId/lastSeen')
        .set(DateTime.now().toIso8601String());
  }

  static void stopSync() => _syncTimer?.cancel();
}
```

---

### UX-K-05 · Loading Skeleton on Game List

**Issue**: When `_isLoading = true`, only a `CircularProgressIndicator` is shown in the center of the screen.

**Solution**: Replace with skeleton cards using shimmer animation:

```dart
if (_isLoading)
  GridView.builder(
    itemCount: 4,
    itemBuilder: (_, __) => _SkeletonGameCard(),
  )
```

---

### UX-K-06 · Live Countdown Timer on Home Screen

**Issue**: `TimerCard` displays static remaining minutes — it does not decrease in real-time when the child is not in a game session.

**Solution**: Add `Timer.periodic(Duration(minutes: 1), ...)` in `HomeScreen` to refresh `_totalPlayedSecondsToday` from storage every minute.

---

## 5. UX Improvements — Parent App

### UX-P-01 · QR Display — Fully Implement

**Issue**: The QR tab in `PairingGuideScreen` and `PairingSetupScreen` only shows placeholder text, not an actual QR code.

**Solution**: Use `PrettyQrView` (already in pubspec):

```dart
import 'package:pretty_qr_code/pretty_qr_code.dart';

// In build():
PrettyQrView.data(
  data: jsonEncode({
    'type': 'pair',
    'familyId': _familyId,
    'appVersion': '1',
  }),
  decoration: const PrettyQrDecoration(
    image: PrettyQrDecorationImage(
      image: AssetImage('assets/logo.png'),
    ),
  ),
)
```

Also add:
- "Max Brightness" button when displaying QR (so it's easy to scan)
- Auto-refresh QR every 5 minutes with a countdown timer

---

### UX-P-02 · Child Detail Screen

Currently `ChildrenManagementScreen` only shows a list. A per-child detail screen is needed:

```
ChildDetailScreen
├── Header: Avatar + Name + Online status
├── Today's Summary Card
│   ├── Progress bar (played/limit)
│   └── Per-game breakdown (small bar chart)
├── Quick Limit Controls (preset buttons: 30m / 1h / 2h / ∞)
├── Button: "Give Extra Time" → Generate Unlock QR
├── Weekly History (7-day mini chart)
└── Danger Zone: Delete child
```

---

### UX-P-03 · Dashboard Home Screen Redesign

**Issue**: `HomeScreen` in the parent app is a copy from the kids app — showing a `TimerCard` that is irrelevant for parents.

**Solution**: Create a new `ParentHomeScreen`:

```
ParentHomeScreen
├── AppBar: "Welcome, [parent name]" + logout icon
├── Summary Strip: Total active children | Total play time today
├── Children List (StreamBuilder from ChildService.streamChildren)
│   └── ChildQuickCard per child
│       ├── Name + avatar + online indicator
│       ├── Mini progress bar
│       └── Tap → ChildDetailScreen
├── FAB: Add child / Generate unlock QR
└── Bottom Nav: Home | Children | Games | Settings
```

---

### UX-P-04 · Login Screen Redesign

**Issue**: `LoginScreen` is just a plain white scaffold with no branding.

**Solution**: Align with the design language of `RegisterScreen` which is already good (dark background, gradient, GameBox logo). Add:
- "Register" button that navigates to `RegisterScreen` (parent)
- Biometric login option (`local_auth` package) after first login

---

### UX-P-05 · Push Notification via FCM

Add `firebase_messaging` for notifications:

| Trigger | Notification |
|---|---|
| Child reaches 80% of daily limit | "⚠️ [Name] has played 48 minutes out of 60 minutes" |
| Child reaches 100% (locked) | "🔒 [Name] has run out of play time" |
| Child scans unlock QR | "✅ [Name] used +30 extra minutes" |
| Child online (lastSeen update) | Silent push to refresh status |

---

## 6. Architecture Improvements

### ARCH-01 · State Management

**Issue**: All screens use `setState` + manual async calls. Play timer state is not shared between widgets.

**Recommendation**: Add `provider` as minimal state management:

```yaml
# gamesbox_kids/pubspec.yaml
dependencies:
  provider: ^6.1.2
```

```dart
// Create GameTimerProvider
class GameTimerProvider extends ChangeNotifier {
  int _totalPlayedSeconds = 0;
  int _dailyLimitSeconds = 3600;
  Timer? _ticker;

  int get remainingSeconds => (_dailyLimitSeconds - _totalPlayedSeconds).clamp(0, _dailyLimitSeconds);
  double get usageRatio => _totalPlayedSeconds / _dailyLimitSeconds;

  void startTracking() { ... }
  void stopTracking() { ... }
  // notifyListeners() on every change
}
```

---

### ARCH-02 · Migrate Shared Widgets to `gamesbox_common`

Add new directory:

```
gamesbox_common/lib/
├── models/           (already exists)
├── services/         (already exists)
└── widgets/          (NEW)
    ├── password_dialog.dart
    ├── section_card.dart
    ├── timer_card.dart
    └── app_selection_screen.dart
```

Update `gamesbox_common/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.5.5
  firebase_core: ^4.10.0
  firebase_auth: ^6.5.2
  firebase_database: ^12.4.2
  flutter_secure_storage: ^9.0.0   # NEW
  crypto: ^3.0.3                   # NEW (move from parent)
  installed_apps: ^1.4.1           # NEW (required for app_selection_screen)
```

---

### ARCH-03 · Secure Storage for Credentials

Replace all sensitive credential storage:

```dart
// gamesbox_common/lib/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _secure = FlutterSecureStorage();

  // PIN — move to secure storage
  static Future<void> saveParentPin(String pin) async {
    await _secure.write(key: 'parent_pin', value: pin);
    // still keep is_registered in SharedPreferences (not sensitive)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsRegistered, true);
  }

  static Future<String> getParentPin() async {
    return await _secure.read(key: 'parent_pin') ?? '1234';
  }

  // OTP Secret — move to secure storage
  static Future<void> saveOtpSecret(String secret) async {
    await _secure.write(key: 'otp_secret', value: secret);
  }

  static Future<String?> getOtpSecret() async {
    return await _secure.read(key: 'otp_secret');
  }
}
```

---

## 7. Firebase Security Rules

Create file `database.rules.json` in the project root:

```json
{
  "rules": {
    "families": {
      "$familyId": {
        ".read": "auth != null && data.child('parentId').val() === auth.uid",
        ".write": "auth != null && (
          !data.exists() ||
          data.child('parentId').val() === auth.uid
        )"
      }
    },
    "kids": {
      "$kidId": {
        ".read": "auth != null && (
          data.child('parentId').val() === auth.uid ||
          auth.uid === $kidId
        )",
        ".write": "auth != null && (
          data.child('parentId').val() === auth.uid ||
          !data.exists()
        )",
        "playedTodaySeconds": {
          ".write": "auth != null"
        },
        "lastSeen": {
          ".write": "auth != null"
        }
      }
    },
    "games": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "time_limits": {
      "$kidId": {
        ".read": "auth != null",
        ".write": "auth != null && root.child('kids').child($kidId).child('parentId').val() === auth.uid"
      }
    },
    "pairing": {
      "$otp": {
        ".read": "auth != null",
        ".write": "auth != null && (
          !data.exists() ||
          data.child('parentId').val() === auth.uid ||
          !data.child('kidId').exists()
        )"
      }
    }
  }
}
```

> **Note**: Kids app needs Firebase authentication (anonymous auth) so that rules can apply. Add `signInAnonymously()` in the kids app on first launch.

---

## 8. New & Modified Files Plan

### New Files to Create

```
gamesbox_common/
└── lib/
    ├── services/
    │   └── qr_unlock_service.dart          ★ NEW
    └── widgets/
        ├── password_dialog.dart            ★ MOVE from kids+parent
        ├── section_card.dart               ★ MOVE from kids+parent
        └── timer_card.dart                 ★ MOVE from kids+parent

gamesbox_kids/
└── lib/
    ├── screens/
    │   ├── kids_splash_screen.dart         ★ NEW
    │   └── locked_screen.dart              ★ NEW
    ├── services/
    │   └── kid_sync_service.dart           ★ NEW
    └── widgets/
        └── skeleton_game_card.dart         ★ NEW

gamesbox_parent/
└── lib/
    ├── screens/
    │   ├── parent_home_screen.dart         ★ NEW (replace home_screen.dart)
    │   └── child_detail_screen.dart        ★ NEW
    └── services/
        └── notification_service.dart       ★ NEW
```

### Files to Modify

```
gamesbox_common/lib/
├── gamesbox_common.dart                    Add new widget exports
└── services/
    ├── firebase_service.dart               Add getCurrentUser(), anonymousSignIn()
    └── storage_service.dart                Migrate PIN + OTP to flutter_secure_storage

gamesbox_kids/lib/
├── main.dart                               Change home to KidsSplashScreen
└── screens/
    ├── pairing_screen.dart                 Add QR scanner tab
    ├── home_screen.dart                    Dynamic name, live timer, skeleton loader
    └── game_session_screen.dart            Periodic sync to Firebase

gamesbox_parent/lib/
├── screens/
│   ├── pairing_screen.dart                 Implement real QR (PrettyQrView)
│   ├── pairing_setup_screen.dart           Implement real QR
│   ├── child_management_screen.dart        Fix getCurrentUser(), tap to detail
│   ├── login_screen.dart                   Redesign + branding
│   └── time_limit_screen.dart              Fix static vs instance bug
└── services/
    ├── otp_service.dart                    Fix randomness
    └── pairing_service.dart                Fix pairing code length
```

---

### `QrUnlockService` Specification

```dart
// gamesbox_common/lib/services/qr_unlock_service.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrUnlockPayload {
  final String kidId;
  final int extraMinutes;
  final int expiresAt; // Unix ms
  final String hmac;

  const QrUnlockPayload({
    required this.kidId,
    required this.extraMinutes,
    required this.expiresAt,
    required this.hmac,
  });

  Map<String, dynamic> toMap() => {
    'type': 'unlock',
    'kidId': kidId,
    'extraMinutes': extraMinutes,
    'expiresAt': expiresAt,
    'hmac': hmac,
  };

  factory QrUnlockPayload.fromMap(Map<String, dynamic> map) => QrUnlockPayload(
    kidId: map['kidId'],
    extraMinutes: map['extraMinutes'],
    expiresAt: map['expiresAt'],
    hmac: map['hmac'],
  );
}

class QrUnlockService {
  static const int _expiryWindowMs = 5 * 60 * 1000; // 5 minutes

  /// Generate QR unlock payload (called from parent app)
  static String generateUnlockQr({
    required String kidId,
    required int extraMinutes,
    required String otpSecret,
  }) {
    final expiresAt = DateTime.now().millisecondsSinceEpoch + _expiryWindowMs;
    final message = '$kidId:$extraMinutes:$expiresAt';
    final hmac = _computeHmac(message, otpSecret);

    final payload = QrUnlockPayload(
      kidId: kidId,
      extraMinutes: extraMinutes,
      expiresAt: expiresAt,
      hmac: hmac,
    );

    return jsonEncode(payload.toMap());
  }

  /// Verify and apply unlock QR (called from kids app)
  /// Returns extraMinutes if valid, throws Exception if not
  static int verifyAndExtract({
    required String qrData,
    required String otpSecret,
    required String expectedKidId,
  }) {
    final map = jsonDecode(qrData) as Map<String, dynamic>;

    if (map['type'] != 'unlock') {
      throw Exception('Not a valid unlock QR');
    }

    final payload = QrUnlockPayload.fromMap(map);

    // Check kidId
    if (payload.kidId != expectedKidId) {
      throw Exception('This QR is not for this device');
    }

    // Check expiry
    if (DateTime.now().millisecondsSinceEpoch > payload.expiresAt) {
      throw Exception('QR has expired. Ask your parent to generate a new one');
    }

    // Verify HMAC
    final message = '${payload.kidId}:${payload.extraMinutes}:${payload.expiresAt}';
    final expectedHmac = _computeHmac(message, otpSecret);
    if (payload.hmac != expectedHmac) {
      throw Exception('QR is invalid or has been tampered with');
    }

    return payload.extraMinutes;
  }

  static String _computeHmac(String message, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(message);
    final hmac = Hmac(sha256, key);
    return base64Encode(hmac.convert(bytes).bytes);
  }
}
```

---

## 9. Implementation Phases

### Phase 1 — Fix Blockers (estimate: 2 days)

**Goal**: Application can be compiled and run without errors.

- [ ] BUG-01: Add `FirebaseService.getCurrentUser()`
- [ ] BUG-02: Fix `TimeLimitService` static consistency
- [ ] BUG-03: Fix kids app startup — create `KidsSplashScreen`
- [ ] BUG-05: Fix `OtpService.generateSecret()` randomness
- [ ] BUG-06: Fix pairing code length
- [ ] Move duplicated widgets/screens to `gamesbox_common`
- [ ] Update all imports in both apps

**Deliverable**: Both apps can build and run without crashes.

---

### Phase 2 — QR Pairing (estimate: 3 days)

**Goal**: Child can pair with parent using QR scan, without typing a manual code.

- [ ] Add `qr_flutter` to parent app
- [ ] Add `mobile_scanner` to kids app
- [ ] Implement QR display in `PairingGuideScreen` (parent) using `PrettyQrView`
- [ ] Implement QR display in `PairingSetupScreen` (parent)
- [ ] Refactor `PairingScreen` (kids) — add Scan QR tab
- [ ] Implement QR payload format (type: "pair")
- [ ] End-to-end test: parent generate QR → kids scan → pairing success → `HomeScreen`
- [ ] Save child name during pairing (UX-K-02)

**Deliverable**: Pairing via QR works end-to-end.

---

### Phase 3 — QR Unlock (estimate: 3 days)

**Goal**: Parents can give extra time via QR scanned by the child.

- [ ] Create `QrUnlockService` in `gamesbox_common`
- [ ] Create `LockedScreen` in kids app (full screen, cannot be dismissed)
- [ ] Integrate `LockedScreen` — replace dialog in `HomeScreen` and `GameSessionScreen`
- [ ] Create `ChildDetailScreen` in parent app
- [ ] Add "Generate Unlock QR" in `ChildDetailScreen`
- [ ] Extra time duration options: 15 / 30 / 60 minutes
- [ ] Implement QR scanner in `LockedScreen` for unlock
- [ ] Verify HMAC + expiry in kids app
- [ ] End-to-end test: locked → scan QR → add time → HomeScreen

**Deliverable**: Unlock flow via QR works end-to-end.

---

### Phase 4 — Firebase Sync & Security (estimate: 2 days)

**Goal**: Real-time data sync between kids and parent, security strengthened.

- [ ] BUG-04: Create `KidSyncService` in kids app
- [ ] Integrate `KidSyncService.startPeriodicSync()` in `GameSessionScreen`
- [ ] Add anonymous sign-in in kids app (`FirebaseAuth.signInAnonymously()`)
- [ ] Create `database.rules.json` and deploy to Firebase
- [ ] Migrate PIN + OTP secret to `flutter_secure_storage`
- [ ] Update `StorageService` with `flutter_secure_storage`
- [ ] Add `firebase_messaging` in parent app
- [ ] Implement `NotificationService` (80% alert, locked, unlock)

**Deliverable**: Real-time data sync, Firebase rules active, credentials secure.

---

### Phase 5 — UX Polish (estimate: 2 days)

**Goal**: Better user experience in both applications.

- [ ] UX-K-05: Skeleton loading in game list
- [ ] UX-K-06: Live countdown on HomeScreen
- [ ] UX-P-01: QR brightness boost when displaying
- [ ] UX-P-03: Redesign `ParentHomeScreen` (multi-child overview)
- [ ] UX-P-04: Redesign `LoginScreen` (branding + dark theme)
- [ ] Accessibility improvements: min tap target 56px, error messages in Indonesian
- [ ] Comprehensive testing of both apps

**Deliverable**: Both apps ready for demo/release.

---

### Timeline Summary

```
Week 1          Week 2
──────────────────────────────────────
Ph.1   Ph.2           Ph.3
[████] [██████████]   [██████████]
                              Ph.4       Ph.5
                              [████████] [████████]
```

| Phase | Duration | Priority |
|---|---|---|
| Phase 1 — Fix Blockers | 2 days | 🔴 Critical |
| Phase 2 — QR Pairing | 3 days | 🔴 Critical |
| Phase 3 — QR Unlock | 3 days | 🟠 High |
| Phase 4 — Firebase Sync & Security | 2 days | 🟠 High |
| Phase 5 — UX Polish | 2 days | 🟡 Medium |
| **Total** | **~12 working days** | |

---

## 10. Additional Technical Notes

### Using `mobile_scanner` on Android

Make sure to add permission in `gamesbox_kids/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### QR Brightness Boost (when displaying in parent app)

```dart
import 'package:flutter/services.dart';

void _boostBrightness() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarBrightness: Brightness.light,
  ));
  // Use screen_brightness package to set brightness to 1.0
}
```

### Kids App — Anonymous Auth

```dart
// In KidsSplashScreen before checking pairing
final auth = FirebaseAuth.instance;
if (auth.currentUser == null) {
  await auth.signInAnonymously();
}
```

### Automatic Daily Reset

`StorageService._checkAndResetDailyIfNeeded()` already exists and works when `getTotalPlayed()` is called. Make sure it's also called on app launch in `KidsSplashScreen`:

```dart
await StorageService.getTotalPlayed(); // trigger reset check
```

### Note on `installed_apps` Package

The `installed_apps` package only works on Android. If there are plans for iOS support, replace with another approach (manual package name input) or hide the add-game feature on iOS.

---

*This document was created based on a review of the GamesBox codebase version June 2026. Update this document whenever there is a change in scope or priority.*
