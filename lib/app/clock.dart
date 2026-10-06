import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time of day, overridable so tests can pin it (e.g. to the evening).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The evening check-in opens from this hour.
const kEveningHour = 18;
