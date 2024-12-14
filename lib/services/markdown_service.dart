import 'package:flutter/material.dart';

class MarkdownValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const MarkdownValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}

class MarkdownService {
  static final RegExp headerPattern = RegExp(r'^#{1,6}\s');
  static final RegExp tagPattern = RegExp(r'@(\w+)');
  static final RegExp referencePattern = RegExp(r'\[\[([^\]]+)\]\]');
  static final RegExp conditionalPattern = RegExp(r'\[\[IF:([^\]]+)\]\]');

  // Maximum nesting level for headers
  static const int maxHeaderLevel = 6;

  // Validate markdown content
  static MarkdownValidationResult validateContent(String content) {
    final List<String> errors = [];
    final List<String> warnings = [];

    // Split content into lines for analysis
    final lines = content.split('\n');
    int currentHeaderLevel = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      // Validate headers
      if (headerPattern.hasMatch(line)) {
        final headerLevel = line.indexOf(' ');
        if (headerLevel > maxHeaderLevel) {
          errors.add('Line ${i + 1}: Header level exceeds maximum of $maxHeaderLevel');
        }
        if (headerLevel > currentHeaderLevel + 1) {
          warnings.add('Line ${i + 1}: Header level skipped, might affect document structure');
        }
        currentHeaderLevel = headerLevel;
      }

      // Validate tags
      final tags = tagPattern.allMatches(line);
      for (final tag in tags) {
        if (!isValidTag(tag.group(1) ?? '')) {
          warnings.add('Line ${i + 1}: Undefined tag "${tag.group(1)}"');
        }
      }

      // Validate references
      final references = referencePattern.allMatches(line);
      for (final ref in references) {
        if (!isValidReference(ref.group(1) ?? '')) {
          warnings.add('Line ${i + 1}: Invalid reference "${ref.group(1)}"');
        }
      }

      // Validate conditional statements
      final conditionals = conditionalPattern.allMatches(line);
      for (final cond in conditionals) {
        if (!isValidConditional(cond.group(1) ?? '')) {
          errors.add('Line ${i + 1}: Invalid conditional statement "${cond.group(1)}"');
        }
      }
    }

    return MarkdownValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  // Get syntax highlighting patterns
  static Map<Pattern, TextStyle> getSyntaxPatterns() {
    return {
      headerPattern: const TextStyle(
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      tagPattern: const TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.w500,
      ),
      referencePattern: const TextStyle(
        color: Colors.purple,
        decoration: TextDecoration.underline,
      ),
      conditionalPattern: const TextStyle(
        color: Colors.orange,
        fontStyle: FontStyle.italic,
      ),
      RegExp(r'\*\*[^*]+\*\*'): const TextStyle(
        fontWeight: FontWeight.bold,
      ),
      RegExp(r'\*[^*]+\*'): const TextStyle(
        fontStyle: FontStyle.italic,
      ),
      RegExp(r'`[^`]+`'): const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Color(0xFFE0E0E0),
      ),
    };
  }

  // Validate individual components
  static bool isValidTag(String tag) {
    // Add your tag validation logic here
    final validTags = ['employee', 'company', 'policy', 'date'];
    return validTags.contains(tag.toLowerCase());
  }

  static bool isValidReference(String reference) {
    // Add your reference validation logic here
    if (reference.startsWith('file:')) {
      return RegExp(r'file:\d+').hasMatch(reference);
    }
    return true;
  }

  static bool isValidConditional(String conditional) {
    // Add your conditional validation logic here
    final validConditions = ['complianceIsRequired', 'isEmployee', 'hasAccess'];
    return validConditions.contains(conditional.trim());
  }

  // Apply syntax highlighting to text
  static TextSpan highlightSyntax(String text) {
    final List<TextSpan> children = [];
    String remaining = text;
    int currentPosition = 0;

    while (remaining.isNotEmpty) {
      bool foundMatch = false;
      int earliestMatch = remaining.length;
      Pattern? matchedPattern;
      Match? foundMatchObj;

      for (final entry in getSyntaxPatterns().entries) {
        final matches = entry.key.allMatches(remaining);
        if (matches.isNotEmpty) {
          final match = matches.first;
          if (match.start < earliestMatch) {
            earliestMatch = match.start;
            matchedPattern = entry.key;
            foundMatchObj = match;
            foundMatch = true;
          }
        }
      }

      if (foundMatch && matchedPattern != null && foundMatchObj != null) {
        if (earliestMatch > 0) {
          children.add(TextSpan(text: remaining.substring(0, earliestMatch)));
        }

        final matchedText = remaining.substring(foundMatchObj.start, foundMatchObj.end);
        children.add(TextSpan(
          text: matchedText,
          style: getSyntaxPatterns()[matchedPattern],
        ));

        remaining = remaining.substring(foundMatchObj.end);
        currentPosition += foundMatchObj.end;
      } else {
        children.add(TextSpan(text: remaining));
        break;
      }
    }

    return TextSpan(children: children);
  }
}
