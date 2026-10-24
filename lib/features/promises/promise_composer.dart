import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import 'promise_ui.dart';

class PromiseComposerDialog extends ConsumerStatefulWidget {
  const PromiseComposerDialog({super.key});
  @override
  ConsumerState<PromiseComposerDialog> createState() =>
      _PromiseComposerDialogState();
}

class _PromiseComposerDialogState extends ConsumerState<PromiseComposerDialog> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _promises = <String>[];
  bool _review = false, _saving = false;
  String? _error;
  int? _editing;
  bool get _hasText => _text.text.trim().isNotEmpty;
  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _add() {
    final value = _text.text.trim();
    if (value.isEmpty || value.length > 300) {
      setState(() => _error = 'Write a promise first.');
      return false;
    }
    setState(() {
      if (_editing != null) {
        _promises[_editing!] = value;
      } else {
        _promises.add(value);
      }
      _editing = null;
      _text.clear();
      _error = null;
    });
    return true;
  }

  void _reviewList() {
    if (_hasText || _promises.isEmpty || _editing != null) {
      if (!_add()) return;
    }
    setState(() => _review = true);
    _focus.unfocus();
  }

  Future<void> _save() async {
    if (_saving || _promises.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(promiseServiceProvider).createBatch(_promises);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Your promises are still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height * .92 -
                        MediaQuery.viewInsetsOf(context).bottom)
                    .clamp(180, double.infinity),
          ),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SingleChildScrollView(
              key: ValueKey(_review),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: g.ink.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _review ? 'Review promises' : 'Add a promise',
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close promises',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_review) ...[
                    Text(
                      'PROMISE ${(_editing ?? _promises.length) + 1}',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: const ValueKey('promise_input'),
                      controller: _text,
                      focusNode: _focus,
                      autofocus: true,
                      maxLength: 300,
                      minLines: 3,
                      maxLines: 5,
                      enabled: !_saving,
                      onChanged: (_) => setState(() => _error = null),
                      style: AppTypography.thoughtContent(
                        color: g.ink,
                      ).copyWith(fontSize: 19),
                      decoration: InputDecoration(
                        hintText: 'What will you stick to today?',
                        hintStyle: AppTypography.thoughtContent(
                          color: g.inkMuted,
                        ).copyWith(fontSize: 19),
                        filled: true,
                        fillColor: g.ink.withValues(alpha: .035),
                        contentPadding: const EdgeInsets.all(16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: g.ink.withValues(alpha: .24),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: g.ink, width: 1.5),
                        ),
                      ),
                    ),
                    if (_promises.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: g.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_promises.length} added to your list',
                              style: TextStyle(color: g.inkMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_hasText || _promises.isEmpty || _editing != null)
                      PromiseActionButton(
                        key: const ValueKey('promise_next'),
                        label: _editing == null
                            ? 'Next promise'
                            : 'Update promise',
                        icon: Icons.arrow_forward,
                        onPressed: _hasText
                            ? () {
                                if (_add()) _focus.requestFocus();
                              }
                            : null,
                      ),
                    const SizedBox(height: 10),
                    if (!_hasText && _promises.isNotEmpty && _editing == null)
                      PromiseActionButton(
                        label: 'Review & save',
                        onPressed: _reviewList,
                      )
                    else if (_promises.isNotEmpty || _hasText)
                      OutlinedButton(
                        onPressed: _reviewList,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: g.ink,
                          minimumSize: const Size(0, 48),
                          side: BorderSide(color: g.ink.withValues(alpha: .45)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Review & save'),
                      ),
                  ] else ...[
                    Text(
                      '${_promises.length} FOR TODAY',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _promises.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${i + 1}'.padLeft(2, '0'),
                                style: TextStyle(
                                  color: g.inkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _promises[i],
                                style: AppTypography.thoughtContent(
                                  color: g.ink,
                                ).copyWith(fontSize: 17),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit promise ${i + 1}',
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _editing = i;
                                      _text.text = _promises[i];
                                      _review = false;
                                    }),
                            ),
                            IconButton(
                              tooltip: 'Remove promise ${i + 1}',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _promises.removeAt(i);
                                      if (_promises.isEmpty) _review = false;
                                    }),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: g.line),
                    ],
                    const SizedBox(height: 16),
                    PromiseActionButton(
                      label: _saving
                          ? 'Saving…'
                          : 'Save ${_promises.length} ${_promises.length == 1 ? 'promise' : 'promises'}',
                      icon: _saving ? null : Icons.check,
                      onPressed: _saving ? null : _save,
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _review = false),
                      child: const Text('Add another promise'),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: TextStyle(color: g.ink)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
