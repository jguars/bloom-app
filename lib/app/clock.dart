import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time of day, overridable so tests can pin it (e.g. to the evening). Code outside widgets reads `clock.now()`
/// (package:clock), which tests pin with `withClock`.
final clockProvider = Provider<DateTime Function()>((ref) => clock.now);

/// The evening check-in opens from this hour.
const kEveningHour = 18;
