import 'dart:convert';

import 'finance_formulas.dart';
import 'llm_agent.dart';
import 'read_only_db.dart';
import 'sql_guard.dart';

/// Orchestrates one chat turn: builds the system prompt (schema + rules),
/// exposes the read-only `query_database` tool, and delegates the agentic
/// tool-loop to an [LlmAgent]. Provider-agnostic — the same service works for
/// Bedrock today and any Phase-2 provider later.
class AiChatService {
  final LlmAgent agent;
  final ReadOnlyDb readOnlyDb;

  /// CREATE TABLE DDL for the whole DB, injected verbatim into the prompt.
  final String schemaDdl;
  final String baseCurrency;

  /// Cap on the JSON size of a single tool result fed back to the model.
  static const int _maxResultChars = 24000;

  AiChatService({
    required this.agent,
    required this.readOnlyDb,
    required this.schemaDdl,
    required this.baseCurrency,
  });

  Future<AiAnswer> ask(String question, {List<ChatTurn> history = const [], String? contextNote}) {
    return agent.run(
      question,
      systemPrompt: _systemPrompt(contextNote),
      tools: [_queryTool],
      history: history,
    );
  }

  ToolSpec get _queryTool => ToolSpec(
    name: 'query_database',
    description:
        'Run a single read-only SQLite SELECT against the user\'s personal '
        'finance database and get the matching rows back as JSON. Call it as '
        'many times as needed to answer the question.',
    inputSchema: const {
      'type': 'object',
      'properties': {
        'sql': {'type': 'string', 'description': 'A single read-only SQLite SELECT statement.'},
      },
      'required': ['sql'],
    },
    run: _runQuery,
  );

  Future<Object?> _runQuery(Map<String, dynamic> input) async {
    final raw = (input['sql'] as String?) ?? '';
    final guard = SqlGuard.validate(raw);
    if (!guard.ok) {
      return {'error': guard.reason, 'sql': raw};
    }
    try {
      final rows = readOnlyDb.select(guard.sql!);
      return _capResult(guard.sql!, rows);
    } catch (e) {
      return {'error': 'SQL error: $e', 'sql': guard.sql};
    }
  }

  Object _capResult(String sql, List<Map<String, Object?>> rows) {
    var included = rows;
    while (included.isNotEmpty && jsonEncode(included).length > _maxResultChars) {
      included = included.sublist(0, included.length ~/ 2);
    }
    final truncated = included.length < rows.length;
    return {
      'sql': sql,
      'rowCount': rows.length,
      if (truncated) 'returnedRows': included.length,
      'rows': included,
    };
  }

  String _systemPrompt(String? contextNote) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final context = (contextNote != null && contextNote.trim().isNotEmpty) ? '\n- App context: ${contextNote.trim()}' : '';
    return '''
You are a financial-data assistant inside a personal-finance app. Answer the
user's questions about THEIR own data by querying a local SQLite database with
the `query_database` tool, then replying in clear natural language.

Rules:
- ALWAYS get facts from `query_database`; never invent numbers. You may call it
  multiple times (e.g. to explore, then refine).
- Use only the tables and columns in the schema below, with SQLite syntax.
- Date/time columns are stored as INTEGER Unix epoch SECONDS. To work with them
  use SQLite's `unixepoch` modifier, e.g. `date(value_date, 'unixepoch')`,
  `strftime('%Y-%m', value_date, 'unixepoch')` to group by month, and
  `strftime('%s', '2025-01-01')` to build epoch bounds for comparisons.
- For transactions/incomes, a positive `amount` is money IN (income/inflow) and
  a negative `amount` is money OUT (expense/outflow). Each row has its own
  `currency`. `value_date` is the authoritative date for ordering and totals;
  `operation_date` is only for import dedup — prefer `value_date`.
- The user's base currency is $baseCurrency. Today is $today.$context
- You cannot see the screen, but the "App context" above states exactly what the
  current view displays. When the user refers to "these charts/graphs", "this
  screen", or "what I'm looking at", treat it as that view's content and answer
  by querying the underlying data with query_database — never refuse for lack of
  visual access.
- After querying, answer concisely with concrete figures and the currency. If a
  query returns nothing relevant, say so plainly. If the question cannot be
  answered from this schema, say that instead of guessing.
- When the user asks about a metric the app reports (net worth, savings,
  expenses, savings rate, investment weight, FIRE, HHI, gain, after-tax value,
  etc.), use the EXACT formula from "App metric definitions" below, applied to
  data you fetch via query_database. Do not invent an alternative formula.

App metric definitions (use these EXACT formulas):
$financeFormulas

Database schema (SQLite CREATE TABLE statements):
$schemaDdl
''';
  }
}
