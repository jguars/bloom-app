# Handoff: Clover's House plan

This folder is a copy of the Bloom app for making the app easier to understand: one promise, rooms that connect,
one progress spine. Start here in a new session.

## The plan

One-page product plan: https://claude.ai/artifact/VdfN6cZ4y1EtJDE5NhwFPt ("Clover's House", private to the owner).

- **Promise:** Bloom helps you build gentle daily habits, moving a little and eating a little better, with Clover, a cat
  who does them with you. Every screen either is one of those habits or shows progress from them.
- **The house:** every tab is a room. Living room = Today, Balcony = Plan, Garage = Shop, Stairs = Progress,
  Bedroom = Profile. Craving corners (kitchen, nook, lane, window) are one tap from the living room's Craving pill.
- **One spine:** two scores only. Paws (what you spend) and steps (your journey: an active day is a step; portraits
  mark milestones; the streak counts steps in a row; a paw patch saves a step). Weight is an optional side line.

### Order of work

1. **Now (clarity, low effort):** the promise in onboarding; tabs named after rooms; a house map in onboarding
   ("Each room is part of your day"); Clover's next-step line in every room; Shop items say which moves they unlock.
2. **Next (one spine):** steps replace flags; the streak counts steps; a post-session card shows the paws chain
   ("+15 paws, 35 more for the kettlebell"); kept habits and ridden-out cravings add to the day; weight in Progress only.
3. **Later (guided first day):** rooms unlock as the story reaches them; day 1 to 7 nudges from Clover.

Measures: a five-person "what is this for?" test after 60 s (before and after); first-day completion (one move, one
habit, first step seen); day-7 return; rooms visited per day.

## Where this copy starts

- Git worktree `bloom-app-house` on branch `house-plan`, made from `roaming-clover` at 73b9441 plus that branch's
  uncommitted work at the time (copied in, not committed): Craving rooms (kitchen water, nook breathing, lane walk,
  window), calf raises at the kitchen counter, rebuilt wall push-ups, one shared title-row pill style (`lib/ui/title_pill.dart`),
  membership testing (Settings › Subscription to cancel Plus; Settings › Testing to borrow paws).
- The original `bloom-app-roaming` folder is untouched; `bloom-app` is `main`.
- Commit and push only when asked.

## Working notes

- **Run and install:** `flutter build apk --release`, then `adb -s f13ad825 install -r build/app/outputs/flutter-apk/app-release.apk`
  (Xiaomi, needs File transfer mode and USB debugging on; adb lives in `~/Library/Android/sdk/platform-tools`). Never
  change the phone's security settings; input injection is blocked on it. iPhone builds need a newer macOS (Xcode).
- **Tests:** `flutter test`. Screenshot tests live in `test/screens_test.dart` (shots in `test/shots/`); update one with
  `flutter test test/screens_test.dart --plain-name "<name>" --update-goldens`. Some fail only because of today's date or
  time of day: alarms, ringing, celebrate, check-in(-picked), log-weight, progress-weight, streak(-celebrate), weekly,
  weight-history, plan-report, paywall, ob-pace, ob-journey, today-dusk/night/dawn/checked-in.
- **Debug builds:** `--dart-define=LAB=true` adds the Move lab in Settings; `PERF=true PERF_TOUR=true`, `MOVE_TOUR=ids`,
  `OB`, `OB_TOUR` are other test tours.
- **Clover's animations (Rive):** the "Clover" file is open in the Rive app, which serves MCP at 127.0.0.1:9791 only while
  a file is open. Scripts: `../avelo/design-system/mascot/model/anim/` (`rive_call.py`, `export_scene.py`, and the move
  scripts `moves3.py`, `bridge3.py`, `craving2.py`, `rooms3.py`). Export scenes into `assets/rive/`. Every move is keyed
  from shared phase curves every 2 frames so body parts stay in sync.
- **Images:** generated in Layer (workspace "weareonkigames"). Ask before any job over 20 credits.
- **Video:** the Remotion project is `..` (`src/compositions/House/`: `BloomAd30`, `HouseAd`); render one at a time.
- Ask when unsure. Tokens and passwords are entered by the user, never by the agent.
