# GamesBox — Parent↔Kids Integration Fix Plan

> Companion to PLANNING.md. PLANNING.md covers the original 5-phase build-out
> (QR pairing/unlock, security, UX). This document addresses what's still
> broken **after** that work landed: games chosen by the parent never reach
> the kid, and the kids app still carries parent-only screens that should no
> longer exist now that the apps are split and pairing works.

---

## 0. Root-cause summary

Tracing the actual data flow (not just file names) surfaces three separate,
disconnected "games" systems:

| System | Storage | Written by | Read by | Per-child? |
|---|---|---|---|---|
| Local `GameEntry` list | `SharedPreferences` key `allowed_games_list` (device-local) | `gamesbox_kids/screens/app_selection_screen.dart` **or** `gamesbox_parent/screens/app_selection_screen.dart` | `gamesbox_kids/screens/home_screen.dart` via `StorageService.getGames()` | No — it's whichever device ran the picker |
| Global `GameModel` list | Firebase `games/` (flat, no child scoping) | `gamesbox_parent/screens/add_game_screen.dart`, `games_list_screen.dart` | `gamesbox_kids/screens/games_list_screen.dart` (a screen that's never navigated to from `HomeScreen`) | No — global, and effectively dead code in the UI flow |
| `ChildModel` / `TimeLimitModel` | Firebase `kids/{id}`, `time_limits/{id}` | parent app | both apps | Yes |

Because `gamesbox_parent/lib/screens/app_selection_screen.dart` is literally
the kids-app file copy-pasted, when a parent runs "Tambah Game" on **their
own phone**, it lists apps **installed on the parent's phone** and saves
them to the **parent's local storage** — which the kid's device can never
see. This is the core bug behind "games picked on parent side don't show up
for the kid." It is not a sync bug, it's a wrong-data-model bug: local
device storage was never meant to cross devices, but the parent flow was
built as if it would.

`Section 2.2` of PLANNING.md already flagged `app_selection_screen.dart` as
duplicated code to "move to common," but moving the *file* doesn't fix this
— the underlying model needs to be per-child and live in Firebase, with
`installed_apps` queried only on the kid's device (since only the kid's
device can know what's actually installed there).

---

## 1. Fix: Parent-selected games reach the paired kid

### 1.1 New data model — `AllowedGame` under `kids/{kidId}/allowedGames`

Replace the local-storage `GameEntry` list (for the *allow-list* purpose)
with a Firebase-synced, per-child list. Icons can't be synced (raw bytes,
device-specific `installed_apps` icon data) so we drop `iconBytes` from the
synced model and let each app resolve its own icon locally from
`installed_apps` by package name when available, falling back to a generic
icon.

```dart
// gamesbox_common/lib/models/allowed_game.dart
class AllowedGame {
  final String packageName;
  final String name;       // display name, parent-entered or scraped
  final String addedBy;     // 'parent' | 'kid' — for future audit/UX
  final String addedAt;     // ISO-8601

  const AllowedGame({
    required this.packageName,
    required this.name,
    required this.addedBy,
    required this.addedAt,
  });

  factory AllowedGame.fromMap(Map<dynamic, dynamic> map) => AllowedGame(
        packageName: map['packageName'] as String? ?? '',
        name: map['name'] as String? ?? '',
        addedBy: map['addedBy'] as String? ?? 'parent',
        addedAt: map['addedAt'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'name': name,
        'addedBy': addedBy,
        'addedAt': addedAt,
      };
}
```

Firebase shape:

```
kids/{kidId}/
  allowedGames/
    {packageNameSafeKey}: { packageName, name, addedBy, addedAt }
```

(Use a sanitized package name — e.g. dots replaced with underscores — as
the key so adding the same package twice naturally overwrites rather than
duplicating.)

### 1.2 New service — `AllowedGamesService` in `gamesbox_common`

```dart
// gamesbox_common/lib/services/allowed_games_service.dart
class AllowedGamesService {
  static DatabaseReference _ref(String kidId) =>
      FirebaseDatabase.instance.ref('kids/$kidId/allowedGames');

  static String _key(String packageName) =>
      packageName.replaceAll('.', '_');

  static Future<void> addGame(String kidId, AllowedGame game) async {
    await _ref(kidId).child(_key(game.packageName)).set(game.toMap());
  }

  static Future<void> removeGame(String kidId, String packageName) async {
    await _ref(kidId).child(_key(packageName)).remove();
  }

  static Stream<List<AllowedGame>> streamGames(String kidId) {
    return _ref(kidId).onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      final raw = event.snapshot.value as Map<dynamic, dynamic>;
      return raw.values
          .map((v) => AllowedGame.fromMap(v as Map<dynamic, dynamic>))
          .toList();
    });
  }

  static Future<List<AllowedGame>> getGamesOnce(String kidId) async {
    final snap = await _ref(kidId).get();
    if (!snap.exists || snap.value == null) return [];
    final raw = snap.value as Map<dynamic, dynamic>;
    return raw.values
        .map((v) => AllowedGame.fromMap(v as Map<dynamic, dynamic>))
        .toList();
  }
}
```

Export from `gamesbox_common.dart`.

### 1.3 Parent side — rewrite the "Tambah Game" flow to write to the child's node

`gamesbox_parent/lib/screens/app_selection_screen.dart` currently calls
`InstalledApps.getInstalledApps()` (apps on the **parent's** phone — wrong)
and `StorageService.saveGames()` (local — wrong). Two real options exist,
and the parent should get **both**, since the parent's phone cannot
enumerate the kid's installed apps:

**Option A — Manual entry by the parent** (works today, no kid-side
dependency): parent types a game name + Play Store / package ID (this
overlaps with the existing-but-orphaned `StoreShareHandler` /
`add_game_screen.dart` flow — see §1.5 for consolidation). Writes straight
to `AllowedGamesService.addGame(kidId, ...)`.

**Option B — Kid requests, parent approves** (better UX, needs new
plumbing): kid's device lists its own installed apps (it's the only device
that can), the kid taps "ask to add," which writes a *pending* request
under `kids/{kidId}/pendingGameRequests/{key}`. Parent's
`ChildDetailScreen` shows a small "Permintaan Game Baru" section, approve
→ `AllowedGamesService.addGame` + remove the pending request; deny →
remove the pending request only.

Recommended scope for this pass: ship **Option A** now (it directly
unblocks "parent picks, kid plays" with no new kid-side screen), and track
Option B as a fast-follow since it reuses the same `AllowedGamesService`
and just adds a `pendingGameRequests` write path + one new card in
`ChildDetailScreen`.

Concretely, replace `gamesbox_parent/lib/screens/app_selection_screen.dart`
with a child-scoped manual-add screen:

```dart
// gamesbox_parent/lib/screens/add_allowed_game_screen.dart
class AddAllowedGameScreen extends StatefulWidget {
  final String kidId;
  const AddAllowedGameScreen({super.key, required this.kidId});
  // form: game name, package name (with validation hint:
  // "com.mojang.minecraftpe" style), Save button ->
  // AllowedGamesService.addGame(kidId, AllowedGame(...))
}
```

Wire it from `ChildDetailScreen` (a new button, e.g. next to "Beri Waktu
Tambahan") and from `ChildrenManagementScreen`'s per-child row, instead of
the old global `AppSelectionScreen` push.

### 1.4 Kid side — `HomeScreen` reads the synced list, resolves local icons

`gamesbox_kids/lib/screens/home_screen.dart._loadData()` currently does:

```dart
final storedGames = await StorageService.getGames(); // WRONG SOURCE
```

Change to stream from Firebase and resolve icons locally:

```dart
// inside _HomeScreenState
StreamSubscription<List<AllowedGame>>? _allowedGamesSub;

void _subscribeAllowedGames() {
  final kidId = ...; // from StorageService.getKidId()
  _allowedGamesSub = AllowedGamesService.streamGames(kidId).listen((allowed) async {
    final List<GameEntry> resolved = [];
    for (final g in allowed) {
      Uint8List? icon;
      try {
        final app = await InstalledApps.getAppInfo(g.packageName);
        icon = app?.icon;
      } catch (_) {}
      resolved.add(GameEntry(
        name: g.name,
        packageName: g.packageName,
        iconBytes: icon,
        totalPlayedSecondsToday: await StorageService.getGamePlayed(g.name),
      ));
    }
    if (mounted) setState(() => _games = resolved);
  });
}
```

`GameCard` already shows a fallback `Icons.gamepad_rounded` when
`iconBytes == null`, so an app not yet installed on the kid's device still
renders cleanly (useful since the parent can add a game before the kid has
installed it).

`StorageService.saveGames()` / `getGames()` / the local `_keyGamesList` can
then be deleted entirely (see §3) — local per-device game lists no longer
have a purpose once this is the source of truth.

### 1.5 Consolidate the orphaned global-games flow

`gamesbox_parent/lib/screens/games_list_screen.dart`,
`add_game_screen.dart`, `games/games_service.dart`, and
`store_share_handler.dart` all write to the **global, non-per-child**
Firebase `games/` node, and `gamesbox_kids/lib/screens/games_list_screen.dart`
+ `game_play_screen.dart` read from it — but nothing in `HomeScreen`
navigates there, so it's currently dead UI. Two choices:

- **Recommended**: retarget `StoreShareHandler` (the Play Store
  share-to-add flow, which is the most polished "find a game" UX already
  built) to call `AllowedGamesService.addGame(kidId, ...)` instead of the
  global `GamesService`, and delete the global `games/` concept along with
  `games_list_screen.dart` (both apps), `add_game_screen.dart`,
  `games_service.dart`, `game_play_screen.dart`, and the kids'
  `games_list_screen.dart`. This collapses three game systems into one.
- **Alternative**: keep `games/` as a parent-curated **catalog** (e.g. a
  pre-approved list of kid-friendly titles parents pick from) feeding into
  `AllowedGamesService` on selection — more product surface, not required
  to unblock the core bug, defer unless wanted.

This plan assumes the **recommended** path since it's the minimal change
that produces one coherent system.

### 1.6 Firebase rules update

`database.rules.json` (PLANNING.md §7) needs a new node:

```json
"kids": {
  "$kidId": {
    "...": "...",
    "allowedGames": {
      ".read": "auth != null && (root.child('kids').child($kidId).child('parentId').val() === auth.uid || auth.uid === $kidId)",
      ".write": "auth != null && (root.child('kids').child($kidId).child('parentId').val() === auth.uid || auth.uid === $kidId)"
    }
  }
}
```

(Kid needs write too, if/when §1.3's Option B — kid-initiated requests — is
implemented under `pendingGameRequests`, which should similarly be
kid-writable / parent-writable, parent-only-deletable on approve/deny.)

---

## 2. Kids app — remove parent-only screens

Once pairing + the parent app fully own configuration, the kid's app should
be a closed, simple surface: pairing (one-time), home (games + time
remaining), game session, locked screen. Everything that lets a child
self-administer limits, PINs, or the game allow-list is leftover from
before the two apps were split and is now both **redundant** (parent app
does this better, with auth) and a **security hole** (a child with the
PIN — or who guesses the default `1234` fallback in
`StorageService.getParentPin()` — can re-open admin controls on their own
device).

### 2.1 Screens/widgets to delete from `gamesbox_kids`

| File | Why it goes |
|---|---|
| `lib/screens/parent_dashboard.dart` | Local-only PIN-gated admin screen (limit slider, game list, reset). Superseded by the parent app's `ChildDetailScreen` + `ChildTimeLimitCard`, which write to Firebase per-child instead of local prefs. |
| `lib/screens/app_selection_screen.dart` | Replaced by §1's Firebase-synced flow; the *parent* decides what's allowed, not local picker on the kid's device. |
| `lib/screens/register_screen.dart` | This is the **parent-PIN setup** screen, mistakenly present in the kids app (compare to `gamesbox_parent/lib/screens/register_screen.dart` — same file, same purpose). Kids should never set the parent PIN from their own device. |
| `lib/widgets/password_dialog.dart` | Only consumer was `HomeScreen._openParentDashboard()`. Goes with the dashboard. |
| `lib/widgets/section_card.dart`, `lib/widgets/timer_card.dart` | Local duplicates already superseded by `gamesbox_common`'s versions (`gamesbox_common/lib/widgets/section_card.dart`, `timer_card.dart`, already exported in `gamesbox_common.dart`). Pure dead weight regardless of this plan — see §3. |
| `lib/widgets/time_remaining_widget.dart` | Unused — no references found anywhere in `home_screen.dart`, `locked_screen.dart`, or `game_session_screen.dart`. Superseded by the `TimerCard` countdown (UX-K-06) and `LockedScreen`'s own countdown. |
| `lib/screens/games_list_screen.dart` + `lib/screens/game_play_screen.dart` | Part of the orphaned global-`games/` system retired in §1.5. |

### 2.2 `HomeScreen` changes

Remove the parent-gate entirely:

```dart
// DELETE: _openParentDashboard() and the face-icon GestureDetector in _buildHeader()
```

Replace the top-right icon (currently `Icons.face_rounded` → opens PIN
dialog) with something that fits a kid-only surface — e.g. nothing, or a
small "Tentang" / help icon, or simply remove that corner of the header.
Recommend: remove the icon entirely and let the header just show the
greeting + avatar, since there's no longer an in-app destination it should
lead to.

Imports to drop from `home_screen.dart`:
```dart
import 'parent_dashboard.dart';   // DELETE
// PasswordDialog comes from gamesbox_common — DELETE that usage too
```

### 2.3 `main.dart` route cleanup

```dart
// gamesbox_kids/lib/main.dart — routes map
routes: {
  '/pairing': (context) => const PairingScreen(),
  '/home':    (context) => const HomeScreen(),
  // DELETE: '/games': (context) => const GamesListScreen(),
},
```

### 2.4 Resulting kids-app screen inventory (post-cleanup)

```
gamesbox_kids/lib/screens/
├── splash_screen.dart        (KidsSplashScreen — entry point)
├── pairing_screen.dart       (QR + manual code, one-time)
├── home_screen.dart          (games grid + live timer)
├── game_session_screen.dart  (active play + sync)
└── locked_screen.dart        (time's up + QR unlock)
```

Five screens, each with one clear job. No PIN, no dashboard, no game
picker, no settings — matching the requirement that kids "stay on the
dashboard and just look at the games and screen time."

### 2.5 `StorageService.getParentPin()` / `saveParentPin()` on the kids side

Once `register_screen.dart` and `password_dialog.dart` are removed from
`gamesbox_kids`, nothing in the kids app calls these methods anymore (they
remain in `gamesbox_common` for the **parent** app's own PIN-gated
features, if any — confirm parent-app usage before fully removing from
`StorageService`; if parent app doesn't use a local PIN gate either, since
parent auth is Firebase email/password, these methods may be fully
removable — flagged for verification in §3, not blindly deleted since
`StorageService` is shared).

---

## 3. Clean-up — unused files across the monorepo

Cross-referencing every file against actual imports/usages found in the
provided sources:

### 3.1 Confirmed unused / dead today (delete now)

| File | Evidence |
|---|---|
| `gamesbox_kids/lib/widgets/time_remaining_widget.dart` | No imports found anywhere in kids app screens. |
| `gamesbox_kids/lib/widgets/section_card.dart` | Shadowed by `gamesbox_common`'s version which is already exported and is what `parent_dashboard.dart` actually imports via `gamesbox_common.dart`. Local copy is unreferenced once `parent_dashboard.dart` is deleted (§2.1) — and even before that, nothing imports the *local* widget file directly (no `import '../widgets/section_card.dart'` found in `parent_dashboard.dart`, which uses `package:gamesbox_common/gamesbox_common.dart`'s `SectionCard`). |
| `gamesbox_kids/lib/widgets/timer_card.dart` | Same situation — `home_screen.dart` imports `TimerCard` from `gamesbox_common`, not the local file. Local file is dead. |
| `gamesbox_kids/lib/widgets/password_dialog.dart` | Goes with §2.1 deletion; also already shadowed by `gamesbox_common`'s `PasswordDialog`, which is what `home_screen.dart` actually used. |
| `gamesbox_parent/lib/widgets/section_card.dart` | Same shadowing issue on the parent side — `parent_dashboard.dart` (parent's own copy) imports from `gamesbox_common`. Confirm no remaining local import before deleting. |
| `gamesbox_parent/lib/widgets/timer_card.dart` | Same — `home_screen.dart` (parent's, soon to be replaced per PLANNING.md UX-P-03) imports `TimerCard` from `gamesbox_common`. |
| `gamesbox_parent/lib/widgets/password_dialog.dart` | Same shadowing — only used via `gamesbox_common` import in the parent's `home_screen.dart`. |
| `gamesbox_kids/lib/screens/parent_dashboard.dart` | Per §2.1. |
| `gamesbox_kids/lib/screens/app_selection_screen.dart` | Per §2.1 / §1.4. |
| `gamesbox_kids/lib/screens/register_screen.dart` | Per §2.1. |
| `gamesbox_kids/lib/screens/games_list_screen.dart` | Per §1.5 / §2.1. |
| `gamesbox_kids/lib/screens/game_play_screen.dart` | Per §1.5 / §2.1. |

### 3.2 Empty placeholder directories (`.gitkeep` only — safe to remove once real files land, or leave as scaffolding)

```
gamesbox_kids/lib/models/.gitkeep
gamesbox_kids/lib/screens/auth/.gitkeep
gamesbox_kids/lib/screens/dashboard/.gitkeep
gamesbox_kids/lib/screens/games/.gitkeep
gamesbox_kids/lib/screens/settings/.gitkeep
gamesbox_kids/lib/services/.gitkeep
gamesbox_kids/lib/utils/.gitkeep
gamesbox_kids/lib/widgets/.gitkeep
gamesbox_parent/lib/models/.gitkeep
gamesbox_parent/lib/screens/auth/.gitkeep
gamesbox_parent/lib/screens/dashboard/.gitkeep
gamesbox_parent/lib/screens/games/.gitkeep
gamesbox_parent/lib/screens/settings/.gitkeep
gamesbox_parent/lib/screens/time_limits/.gitkeep
gamesbox_parent/lib/services/.gitkeep
gamesbox_parent/lib/widgets/.gitkeep
```

These are unused scaffold folders from an earlier, different planned
structure (`auth/`, `dashboard/`, `games/`, `settings/`, `time_limits/`
subfolders) that the project ultimately didn't adopt — real screens live
flat under `lib/screens/`. Recommend deleting the empty subdirectories
(`auth/`, `dashboard/`, `games/`, `settings/`, `time_limits/`) since they
add navigation noise with zero content; the top-level `.gitkeep`s for
`models/`, `services/`, `utils/`, `widgets/` can stay since those
directories do hold real files already.

### 3.3 Duplicate "RegisterScreen" naming collision (needs resolution, not just cleanup)

There are **two unrelated screens both named `RegisterScreen`** in
`gamesbox_parent`:

- `gamesbox_parent/lib/screens/register_screen.dart` — a **local PIN-setup**
  flow (`StorageService.saveParentPin`), navigates to the parent's own
  `home_screen.dart`. This looks like another leftover from the
  pre-split single-app era (it mirrors the kids-app version almost
  exactly) and conflicts conceptually with...
- `gamesbox_parent/lib/screens/register_screen_parent.dart` — the **real**
  Firebase email/password registration flow (`FirebaseService.registerParent`
  + OTP secret + `createFamily`), which is what `PLANNING.md` §3.1
  describes and what the actual pairing flow depends on.

Neither is currently wired up in `main.dart` (`ParentApp.home` is
`LoginScreen`, and `LoginScreen._register()` calls `AuthService.register()`
directly, bypassing both of these screen files). This needs a decision,
not silent deletion:

- If local PIN gating on the parent app is intentionally being dropped in
  favor of Firebase auth only (consistent with `LoginScreen` already not
  using either file), delete `register_screen.dart` (the PIN one) and
  rename `register_screen_parent.dart` → `register_screen.dart`, then wire
  `LoginScreen`'s "Register" button to push it instead of calling
  `AuthService.register()` inline (gets the user the OTP-secret +
  `createFamily()` setup that inline registration currently skips
  entirely — this is itself a bug: today's `LoginScreen._register()` path
  never creates a family or OTP secret, so a parent who registers via
  the "Register" link on the login screen can never produce a pairing
  QR/code).
- Flagging this as a **blocker-adjacent bug**: separate from naming
  cleanup, `LoginScreen._register()` must be fixed regardless of which
  file wins, since right now the only path that actually creates a family
  + OTP secret is `RegisterScreen` (the `register_screen_parent.dart` one)
  — which nothing currently navigates to.

### 3.4 `gamesbox_parent/lib/screens/splash_screen.dart` — unreferenced

`main.dart`'s `ParentApp.home` is `LoginScreen` directly; nothing
references `SplashScreen`. Either wire it in as the actual entry point
(it has the `isRegistered()` check logic that decides Home vs Register —
useful, currently dead) or delete it. Given the kids app has an equivalent
`KidsSplashScreen` that *is* wired in as `home`, the more consistent fix is
to wire this one in too rather than delete it — flagged as a small
follow-up, not deletion.

### 3.5 Files to keep despite looking redundant (false positives, confirmed in-use)

- `gamesbox_common/lib/widgets/skeleton_game_card.dart` — used by
  `gamesbox_kids/home_screen.dart` (UX-K-05), correctly exported.
- `gamesbox_kids/lib/services/kid_sync_service.dart`,
  `pairing_service.dart` — actively used by `game_session_screen.dart`,
  `pairing_screen.dart`, `locked_screen.dart`.
- `gamesbox_parent/lib/services/notification_service.dart` — wired into
  `parent_dashboard_screen.dart` initState.
- `gamesbox_parent/lib/widgets/otp_display_widget.dart` — used by
  `pairing_setup_screen.dart`.
- `gamesbox_parent/lib/widgets/child_time_limit_card.dart` — used by
  `child_management_screen.dart`.

---

## 4. Updated `gamesbox_common.dart` exports

```dart
library gamesbox_common;

// Models
export 'models/child_model.dart';
export 'models/game_entry.dart';
export 'models/game_model.dart';        // keep only if §1.5's "alternative" catalog path is chosen later; otherwise remove alongside games_service.dart
export 'models/time_limit_model.dart';
export 'models/allowed_game.dart';      // NEW

// Services
export 'services/firebase_service.dart';
export 'services/storage_service.dart';
export 'services/qr_unlock_service.dart';
export 'services/allowed_games_service.dart'; // NEW

// Shared Widgets
export 'widgets/password_dialog.dart';
export 'widgets/section_card.dart';
export 'widgets/timer_card.dart';
export 'widgets/skeleton_game_card.dart';
```

---

## 5. Implementation order

1. **Add `AllowedGame` model + `AllowedGamesService`** in `gamesbox_common`
   (additive, no breakage).
2. **Update Firebase rules** to allow read/write on
   `kids/{id}/allowedGames` (§1.6).
3. **Wire kid's `HomeScreen`** to stream from `AllowedGamesService` instead
   of `StorageService.getGames()` (§1.4). At this point games added via the
   *old* local picker stop showing up — expected, since that picker is
   being retired.
4. **Build parent's `AddAllowedGameScreen`** (or retarget
   `StoreShareHandler`) to write into the new per-child node (§1.3/§1.5).
   Wire it from `ChildDetailScreen` / `ChildrenManagementScreen`.
5. **End-to-end test**: pair a kid device → parent adds a game by package
   name → kid's `HomeScreen` updates live (StreamBuilder, no refresh
   needed) → kid can launch it (subject to remaining time).
6. **Delete kids-app parent-only screens** (§2.1) and clean imports/routes
   (§2.2, §2.3).
7. **Delete shadowed local widget duplicates** in both apps (§3.1).
8. **Resolve the `RegisterScreen` collision** (§3.3) and fix
   `LoginScreen._register()` to actually create a family + OTP secret.
9. **Remove empty scaffold subdirectories** (§3.2).
10. **Full rebuild of both apps**, confirm no broken imports from deleted
    files (`flutter analyze` on each package).

---

## 6. Open questions for the user before deleting anything

- **Option A vs B in §1.3**: ship manual-entry-only for now, or invest in
  the kid-requests/parent-approves flow in the same pass? This plan
  assumes manual-only first.
- **§1.5**: OK to retire the global `games/` Firebase node and its four
  associated files entirely, or is there a separate "shared game catalog
  across all families" feature planned that depends on it?
- **§3.3**: confirm intent to drop local PIN gating on the parent app in
  favor of Firebase auth only — this affects whether
  `gamesbox_parent/lib/screens/register_screen.dart` (PIN version) is
  deleted or kept as a secondary in-app lock.
- **§3.4**: wire up `gamesbox_parent/lib/screens/splash_screen.dart` as the
  real entry point, or delete it?
