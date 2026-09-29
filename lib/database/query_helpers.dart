import 'package:drift/drift.dart';

import 'package:finance_copilot/utils/visualization_clock.dart';

/// The variable of an "as of [through]" custom query's `date < ?` bound: the
/// start of the day after [through], in epoch seconds as Drift stores a
/// DateTime — every instant of that day is in, none of the next. None when
/// [through] is null: the query then leaves the bound out.
List<Variable<int>> throughVars(DateTime? through) =>
    through == null ? const [] : [Variable.withInt(startOfNextDay(through).millisecondsSinceEpoch ~/ 1000)];
