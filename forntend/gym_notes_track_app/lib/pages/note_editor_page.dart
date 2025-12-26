import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../bloc/note/note_bloc.dart';
import '../bloc/note/note_event.dart';
import '../models/note.dart';

class NoteEditorPage extends StatefulWidget {
  final String folderId;
  final Note? note;

  const NoteEditorPage({super.key, required this.folderId, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _contentFocusNode;
  bool _hasChanges = false;
  bool _isPreviewMode = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _contentFocusNode = FocusNode();

    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  void _onTextChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'New Note' : 'Edit Note'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: Icon(_isPreviewMode ? Icons.edit : Icons.visibility),
            onPressed: () {
              setState(() {
                _isPreviewMode = !_isPreviewMode;
                if (!_isPreviewMode) {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _contentFocusNode.requestFocus();
                  });
                }
              });
            },
            tooltip: _isPreviewMode ? 'Edit' : 'Preview',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _hasChanges ? _saveNote : null,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter note title',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _isPreviewMode
                  ? Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Markdown(
                        data: _contentController.text.isEmpty
                            ? '*No content yet*'
                            : _contentController.text,
                        selectable: true,
                        padding: const EdgeInsets.all(16),
                      ),
                    )
                  : TextField(
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        hintText: 'Write your note...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
          if (!_isPreviewMode) _buildMarkdownToolbar(),
        ],
      ),
    );
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note cannot be empty')));
      return;
    }

    if (widget.note == null) {
      context.read<NoteBloc>().add(
        CreateNote(folderId: widget.folderId, title: title, content: content),
      );
    } else {
      context.read<NoteBloc>().add(
        UpdateNote(noteId: widget.note!.id, title: title, content: content),
      );
    }

    setState(() {
      _hasChanges = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Note saved!')));

    Navigator.pop(context);
  }

  Widget _buildMarkdownToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(top: BorderSide(color: Colors.grey.shade400)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _buildToolbarButton(
              child: const Text(
                'H1',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _insertMarkdown('# ', ''),
            ),
            _buildToolbarButton(
              child: const Text(
                'H2',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _insertMarkdown('## ', ''),
            ),
            _buildToolbarButton(
              child: const Text(
                'H3',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _insertMarkdown('### ', ''),
            ),
            const SizedBox(width: 8),
            _buildToolbarButton(
              child: const Text(
                'B',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _insertMarkdown('**', '**'),
            ),
            _buildToolbarButton(
              child: const Text(
                'I',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
              onPressed: () => _insertMarkdown('_', '_'),
            ),
            _buildToolbarButton(
              child: const Text(
                'S',
                style: TextStyle(
                  fontSize: 16,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              onPressed: () => _insertMarkdown('~~', '~~'),
            ),
            const SizedBox(width: 8),
            _buildToolbarButton(
              child: const Text('• List', style: TextStyle(fontSize: 14)),
              onPressed: () => _insertMarkdown('- ', ''),
            ),
            _buildToolbarButton(
              child: const Text('1. List', style: TextStyle(fontSize: 14)),
              onPressed: () => _insertMarkdown('1. ', ''),
            ),
            _buildToolbarButton(
              child: const Text('☐ Task', style: TextStyle(fontSize: 14)),
              onPressed: () => _insertMarkdown('- [ ] ', ''),
            ),
            const SizedBox(width: 8),
            _buildToolbarButton(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_quote, size: 16),
                  SizedBox(width: 4),
                  Text('Quote', style: TextStyle(fontSize: 14)),
                ],
              ),
              onPressed: () => _insertMarkdown('> ', ''),
            ),
            _buildToolbarButton(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: const Text(
                  'Code',
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              onPressed: () => _insertMarkdown('`', '`'),
            ),
            _buildToolbarButton(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.code, size: 16),
                  SizedBox(width: 4),
                  Text('Block', style: TextStyle(fontSize: 14)),
                ],
              ),
              onPressed: () => _insertMarkdown('```\n', '\n```'),
            ),
            const SizedBox(width: 8),
            _buildToolbarButton(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, size: 16),
                  SizedBox(width: 4),
                  Text('Link', style: TextStyle(fontSize: 14)),
                ],
              ),
              onPressed: () => _insertMarkdown('[', '](url)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarButton({
    required Widget child,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: child,
        ),
      ),
    );
  }

  void _insertMarkdown(String before, String after) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    String selectedText = '';
    if (start >= 0 && end >= 0 && start != end) {
      selectedText = text.substring(start, end);
    }

    final newText =
        text.substring(0, start) +
        before +
        selectedText +
        after +
        text.substring(end);

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + before.length + selectedText.length,
      ),
    );

    _contentFocusNode.requestFocus();
    _onTextChanged();
  }
}
