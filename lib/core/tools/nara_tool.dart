import 'dart:async';

import '../models/execution.dart';
import '../platform/platform_exception.dart';

/// Execution context handed to every tool.
class ToolContext {
  const ToolContext({required this.locale});
  final String locale; // 'id' or 'en'
}

/// Standardized tool schema (spec §9). Every tool validates its own input
/// before executing; handlers may only use the platform bridges — never
/// arbitrary shell/code execution.
abstract class NaraTool {
  String get name;
  String get description;
  Map<String, ToolParam> get inputSchema;
  Duration get timeout => const Duration(seconds: 10);

  RiskLevel get riskLevel;

  /// Validates [args] against [inputSchema]; throws [ToolValidationError].
  void validate(Map<String, Object?> args) {
    for (final entry in inputSchema.entries) {
      final param = entry.value;
      final value = args[entry.key];
      if (value == null) {
        if (param.required) {
          throw ToolValidationError('Missing required argument "${entry.key}" for $name');
        }
        continue;
      }
      final ok = switch (param.type) {
        ToolParamType.string => value is String && value.trim().isNotEmpty,
        ToolParamType.integer => value is int,
        ToolParamType.number => value is num,
        ToolParamType.boolean => value is bool,
        ToolParamType.list => value is List,
      };
      if (!ok) {
        throw ToolValidationError(
          'Argument "${entry.key}" for $name must be ${param.type.name}',
        );
      }
    }
    // Reject unknown arguments to keep plans tight and auditable.
    for (final key in args.keys) {
      if (!inputSchema.containsKey(key) && args[key] != null) {
        throw ToolValidationError('Unknown argument "$key" for $name');
      }
    }
  }

  Future<ActionResult> execute(Map<String, Object?> args, ToolContext context);

  /// Verifies what actually happened after execution. Defaults to the
  /// handler's own report; individual tools may override with deeper checks.
  Future<ActionResult> verify(ActionResult result, ToolContext context) async => result;
}

enum ToolParamType { string, integer, number, boolean, list }

class ToolParam {
  const ToolParam({
    required this.type,
    required this.description,
    this.required = false,
    this.defaultValue,
  });

  final ToolParamType type;
  final String description;
  final bool required;
  final Object? defaultValue;
}

class ToolValidationError implements Exception {
  ToolValidationError(this.message);
  final String message;

  @override
  String toString() => 'ToolValidationError: $message';
}

class ToolExecutionError implements Exception {
  ToolExecutionError(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'ToolExecutionError: $message';
}

/// Runs a tool with validation, timeout and honest error mapping.
Future<ActionResult> runTool(
  NaraTool tool,
  Map<String, Object?> args,
  ToolContext context,
) async {
  try {
    tool.validate(args);
  } on ToolValidationError catch (e) {
    return ActionResult.failure(e.message, 'VALIDATION');
  }
  try {
    final result = await tool.execute(args, context).timeout(tool.timeout);
    return await tool.verify(result, context);
  } on ToolExecutionError catch (e) {
    return ActionResult.failure(e.message, e.code ?? 'TOOL_ERROR');
  } on NaraPlatformException catch (e) {
    return ActionResult.failure(e.message, e.code);
  } on TimeoutException {
    return ActionResult.failure('Tool "${tool.name}" timed out', 'TIMEOUT');
  } catch (e) {
    return ActionResult.failure('Tool "${tool.name}" failed: $e', 'UNEXPECTED');
  }
}
