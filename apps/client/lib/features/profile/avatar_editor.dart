import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/avatar_view.dart';
import '../../design/court_scene.dart';
import '../../domain/avatar_config.dart';
import '../../l10n/app_strings.dart';
import 'avatar_color_picker.dart';
import 'avatar_options.dart';

/// The sheet belongs to the editor body, keeping the screen's save footer free.
class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    required this.config,
    required this.nameController,
    required this.onChanged,
    required this.onNameChanged,
    this.onNameEditingComplete,
    this.onRandomize,
    this.notice,
    this.keyPrefix = '',
    this.nameKey = const ValueKey('profile-name'),
    this.previewKey = const ValueKey('profile-avatar-preview'),
    super.key,
  });
  final AvatarConfig config;
  final TextEditingController nameController;
  final ValueChanged<AvatarConfig> onChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onNameEditingComplete, onRandomize;
  final Widget? notice;
  final String keyPrefix;
  final Key nameKey, previewKey;
  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  String? _option;
  double _dismissDrag = 0;
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_nameFocusChanged);
  }

  void _nameFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_nameFocusChanged);
    _nameFocus.dispose();
    super.dispose();
  }

  void _closeSheet() => setState(() => _option = null);
  void _openSheet(String key) {
    _nameFocus.unfocus();
    setState(() => _option = key);
  }

  @override
  Widget build(BuildContext context) {
    final english = AppLanguageScope.of(context).language == 'en';
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return PopScope(
      canPop: _option == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _option != null) _closeSheet();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_option != null) {
              _closeSheet();
            } else {
              _nameFocus.unfocus();
            }
          },
        },
        child: LayoutBuilder(
          builder: (context, bounds) {
            final available = bounds.maxHeight;
            // Scaffold removes MediaQuery's bottom inset from its resized body.
            final keyboard = View.of(context).viewInsets.bottom > 0;
            final showOptions = !keyboard && available >= 100;
            final portraitHeight = math.min(
              300.0,
              math.min(
                math.min(
                  math.max(0.0, available - (showOptions ? 80 : 10)),
                  showOptions ? math.max(100.0, available * .43) : available,
                ),
                math.max(0.0, bounds.maxWidth - 80) *
                    TrinkAvatarRenderer.visibleHeight /
                    TrinkAvatarRenderer.canvasWidth,
              ),
            );
            final portraitWidth =
                portraitHeight *
                TrinkAvatarRenderer.canvasWidth /
                TrinkAvatarRenderer.visibleHeight;
            final fullHeight =
                portraitWidth *
                TrinkAvatarRenderer.canvasHeight /
                TrinkAvatarRenderer.canvasWidth;
            // The held board begins around y=776 in the 1080 px source artwork.
            final sheetTop = math.min(available, 6 + fullHeight * (776 / 1080));
            final current = _option;
            return Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(),
                          AvatarView(
                            key: widget.previewKey,
                            config: widget.config,
                            size: portraitWidth,
                            playerName: widget.nameController.text,
                            label: context.tr('profilePreview'),
                            nameplateChild: _nameplate(context),
                            onNameplateTap: _nameFocus.requestFocus,
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: widget.onRandomize == null
                                  ? const SizedBox.shrink()
                                  : IconButton(
                                      key: const ValueKey('avatar-randomize'),
                                      tooltip: context.tr('profileRandom'),
                                      icon: const Icon(Icons.shuffle_rounded),
                                      onPressed: widget.onRandomize,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.notice != null)
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: widget.notice,
                          ),
                        ),
                      ),
                    if (showOptions)
                      Expanded(
                        flex: 5,
                        child: AvatarOptions(
                          config: widget.config,
                          keyPrefix: widget.keyPrefix,
                          onOpenSheet: _openSheet,
                        ),
                      ),
                  ],
                ),
                if (current != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: sheetTop,
                    bottom: 0,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(current),
                      tween: Tween(begin: 24, end: 0),
                      duration: duration,
                      builder: (context, offset, child) => Transform.translate(
                        offset: Offset(0, offset),
                        child: child,
                      ),
                      child: Focus(
                        autofocus: true,
                        child: BottomSheet(
                          key: const ValueKey('avatar-editor-sheet'),
                          enableDrag: false,
                          onClosing: _closeSheet,
                          backgroundColor: CourtSceneTokens.panel,
                          elevation: 8,
                          clipBehavior: Clip.antiAlias,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            side: BorderSide(color: CourtSceneTokens.gold),
                          ),
                          builder: (context) => Column(
                            children: [
                              GestureDetector(
                                key: const ValueKey('avatar-sheet-header'),
                                behavior: HitTestBehavior.opaque,
                                onVerticalDragStart: (_) => _dismissDrag = 0,
                                onVerticalDragUpdate: (details) =>
                                    _dismissDrag += details.delta.dy,
                                onVerticalDragEnd: (details) {
                                  if (_dismissDrag > 30 ||
                                      (details.primaryVelocity ?? 0) > 200) {
                                    _closeSheet();
                                  }
                                },
                                child: Column(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 4,
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        color: CourtSceneTokens.gold,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              avatarOptionLabels[current]![english
                                                  ? 1
                                                  : 0],
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: CourtSceneTokens.cream,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            key: const ValueKey(
                                              'avatar-sheet-close',
                                            ),
                                            tooltip: MaterialLocalizations.of(
                                              context,
                                            ).closeButtonTooltip,
                                            onPressed: _closeSheet,
                                            icon: const Icon(
                                              Icons.close,
                                              color: CourtSceneTokens.cream,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: AvatarCatalog.colorKeys.contains(current)
                                    ? AvatarColorPicker(
                                        key: ValueKey(current),
                                        initialHex: widget.config[current],
                                        english: english,
                                        onChanged: (value) => widget.onChanged(
                                          widget.config.withOption(
                                            current,
                                            value,
                                          ),
                                        ),
                                      )
                                    : _variants(current, english),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _nameplate(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final fontSize =
          math.min(20.0, math.max(10.0, bounds.maxHeight * .65)) / textScale;
      return Semantics(
        label: context.tr('profileName'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TextField(
              key: widget.nameKey,
              controller: widget.nameController,
              focusNode: _nameFocus,
              maxLength: 24,
              maxLines: 1,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              cursorColor: CourtSceneTokens.cream,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: _nameFocus.hasFocus
                    ? const Color(0xFFF6E1BA)
                    : Colors.transparent,
                height: 1.1,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintStyle: TextStyle(
                  color: _nameFocus.hasFocus
                      ? CourtSceneTokens.cream.withValues(alpha: .7)
                      : Colors.transparent,
                ),
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: CourtSceneTokens.gold),
                ),
              ),
              onChanged: widget.onNameChanged,
              onEditingComplete: () {
                _nameFocus.unfocus();
                widget.onNameEditingComplete?.call();
              },
            ),
            if (!_nameFocus.hasFocus)
              IgnorePointer(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.nameController.text.trim().isEmpty
                          ? context.tr('profileName')
                          : widget.nameController.text.trim(),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: math.min(20, bounds.maxHeight * .65),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF6E1BA),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _variants(String category, bool english) => GridView.builder(
    key: ValueKey('avatar-variants-$category'),
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    itemCount: AvatarCatalog.options[category]!.length,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 110,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemBuilder: (context, index) {
      final variant = AvatarCatalog.options[category]![index];
      final selected = widget.config[category] == variant;
      return Semantics(
        button: true,
        selected: selected,
        label: variant == 'none'
            ? (english ? 'None' : 'Keine')
            : '${avatarOptionLabels[category]![english ? 1 : 0]} ${index + 1}',
        child: Material(
          color: selected ? const Color(0xFF714A32) : const Color(0xFF26130D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? CourtSceneTokens.gold : const Color(0xFF714A32),
              width: selected ? 3 : 1,
            ),
          ),
          child: InkWell(
            key: ValueKey('avatar-variant-$category-$variant'),
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                widget.onChanged(widget.config.withOption(category, variant)),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, bounds) => Center(
                  child: AvatarPartPreview(
                    config: widget.config,
                    category: category,
                    variant: variant,
                    size: math.min(bounds.maxWidth, bounds.maxHeight),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
