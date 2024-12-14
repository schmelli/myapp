import 'package:flutter/material.dart';
import '../services/markdown_service.dart';

class MarkdownEditor extends StatefulWidget {
  final String initialValue;
  final void Function(String) onChanged;
  final bool showValidation;

  const MarkdownEditor({
    super.key,
    required this.initialValue,
    required this.onChanged,
    this.showValidation = true,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;
  List<String> _errors = [];
  List<String> _warnings = [];
  bool _isValidating = false;
  final FocusNode _focusNode = FocusNode();

  // For tag completion
  bool _showTagCompletion = false;
  String _currentTag = '';
  final List<String> _tagSuggestions = ['employee', 'company', 'policy', 'date'];
  final ScrollController _suggestionsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showTagCompletion = false;
      });
    }
  }

  void _handleTextChange() {
    widget.onChanged(_controller.text);
    if (widget.showValidation) {
      _validateContent();
    }
    _checkForTagCompletion();
  }

  void _validateContent() {
    if (_isValidating) return;
    _isValidating = true;

    final result = MarkdownService.validateContent(_controller.text);
    
    setState(() {
      _errors = result.errors;
      _warnings = result.warnings;
      _isValidating = false;
    });
  }

  void _checkForTagCompletion() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;

    final text = _controller.text.substring(0, selection.start);
    final match = RegExp(r'@(\w*)$').firstMatch(text);

    setState(() {
      if (match != null) {
        _currentTag = match.group(1) ?? '';
        _showTagCompletion = true;
      } else {
        _showTagCompletion = false;
      }
    });
  }

  void _insertTag(String tag) {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final currentPosition = selection.start;
    final lastAtSymbol = text.lastIndexOf('@', currentPosition);

    if (lastAtSymbol != -1) {
      final newText = text.replaceRange(lastAtSymbol + 1, currentPosition, tag);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: lastAtSymbol + tag.length + 1,
        ),
      );
    }

    setState(() {
      _showTagCompletion = false;
    });
  }

  List<String> _getFilteredSuggestions() {
    if (_currentTag.isEmpty) return _tagSuggestions;
    return _tagSuggestions
        .where((tag) => tag.toLowerCase().contains(_currentTag.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(16),
                ),
                onChanged: (value) => widget.onChanged(value),
                keyboardType: TextInputType.multiline,
              ),
              if (_showTagCompletion)
                Positioned(
                  left: 16,
                  top: _focusNode.rect.bottom + 5,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 200,
                        maxWidth: 200,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        controller: _suggestionsScrollController,
                        shrinkWrap: true,
                        itemCount: _getFilteredSuggestions().length,
                        itemBuilder: (context, index) {
                          final suggestion = _getFilteredSuggestions()[index];
                          return ListTile(
                            dense: true,
                            title: Text(suggestion),
                            onTap: () => _insertTag(suggestion),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.showValidation && (_errors.isNotEmpty || _warnings.isNotEmpty))
          Container(
            height: 100,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                ..._errors.map((error) => Text(
                      error,
                      style: const TextStyle(color: Colors.red),
                    )),
                ..._warnings.map((warning) => Text(
                      warning,
                      style: const TextStyle(color: Colors.orange),
                    )),
              ],
            ),
          ),
      ],
    );
  }
}
