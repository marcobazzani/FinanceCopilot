import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The label of the open menu's [value] entry. A menu item's own render box
/// sits under the ink well that takes the tap, so tapping the item itself
/// reports a missed hit test (the tap works, the warning is noise); the label
/// inside it is what the pointer lands on.
Finder dropdownMenuLabel<T>(T value) =>
    find.descendant(of: find.byWidgetPredicate((w) => w is DropdownMenuItem<T> && w.value == value).last, matching: find.byType(Text));
