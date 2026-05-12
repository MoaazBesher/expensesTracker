import 'package:flutter/material.dart';

/// Shared root [Navigator] key for [MaterialApp]. Used for reliable back handling
/// (closing dialogs/sheets) without import cycles.
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();
