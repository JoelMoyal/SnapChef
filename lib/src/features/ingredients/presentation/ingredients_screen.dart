import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/ingredient.dart';
import '../application/ingredient_scan_controller.dart';
import '../data/ingredient_repository.dart';
import '../data/photo_picker.dart';
import 'recommendations_screen.dart';

/// Owner: Joël — ingredient capture & recommendations.
///
/// Take or choose a photo, check what was recognized, fix it by hand, then
/// confirm the list for recommendations. Typing ingredients always works, so a
/// failed scan never blocks the user.
class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  final _newIngredient = TextEditingController();
  final _newIngredientFocus = FocusNode();

  IngredientScanController get _scanner =>
      ref.read(ingredientScanProvider.notifier);

  @override
  void dispose() {
    _newIngredient.dispose();
    _newIngredientFocus.dispose();
    super.dispose();
  }

  void _addTyped() {
    final text = _newIngredient.text;
    if (text.trim().isEmpty) {
      _newIngredientFocus.unfocus();
      return;
    }
    _newIngredient.clear();
    if (_scanner.add(text) == 0) {
      _showSnackBar(
        const SnackBar(content: Text('That’s already on your list.')),
      );
    }
  }

  Future<void> _rename(Ingredient ingredient) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(name: ingredient.name),
    );
    if (name != null) _scanner.rename(ingredient.id, name);
  }

  void _remove(Ingredient ingredient) {
    final index = _scanner.remove(ingredient.id);
    _showSnackBar(
      SnackBar(
        content: Text('Removed ${ingredient.name}'),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _scanner.restore(index, ingredient),
        ),
      ),
    );
  }

  void _showSnackBar(SnackBar snackBar) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  void _findRecipes() {
    _scanner.confirm();
    Navigator.of(context).push(RecommendationsScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final scan = ref.watch(ingredientScanProvider);
    final theme = Theme.of(context);
    final ingredients = scan.ingredients;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                'What’s in your kitchen?',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Snap your fridge, pantry or groceries. We’ll list what we '
                'see, and you can fix anything we get wrong.',
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: scan.analyzing
                          ? null
                          : () => _scanner.scan(PhotoSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: scan.analyzing
                          ? null
                          : () => _scanner.scan(PhotoSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose photo'),
                    ),
                  ),
                ],
              ),
              _ScanStatusView(
                status: scan.status,
                onRetry: _scanner.retry,
                onTypeInstead: _newIngredientFocus.requestFocus,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _newIngredient,
                focusNode: _newIngredientFocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                // Keeps the keyboard open to type several in a row.
                onEditingComplete: _addTyped,
                decoration: InputDecoration(
                  labelText: 'Add an ingredient',
                  hintText: 'For example: eggs, spinach',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add ingredient',
                    onPressed: _addTyped,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                ingredients.isEmpty
                    ? 'Your ingredients'
                    : 'Your ingredients (${ingredients.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (ingredients.isEmpty)
                Text(
                  'Nothing here yet. Take a photo or type an ingredient.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                )
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ingredient in ingredients)
                      InputChip(
                        key: ValueKey(ingredient.id),
                        label: Text(ingredient.name),
                        tooltip: 'Rename ${ingredient.name}',
                        onPressed: () => _rename(ingredient),
                        onDeleted: () => _remove(ingredient),
                        deleteButtonTooltipMessage: 'Remove ${ingredient.name}',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap an ingredient to rename it.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: ingredients.isEmpty || scan.analyzing
                  ? null
                  : _findRecipes,
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Find recipes'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Progress or the outcome of the last scan, below the photo buttons.
class _ScanStatusView extends StatelessWidget {
  const _ScanStatusView({
    required this.status,
    required this.onRetry,
    required this.onTypeInstead,
  });

  final ScanStatus status;
  final VoidCallback onRetry;
  final VoidCallback onTypeInstead;

  @override
  Widget build(BuildContext context) {
    final typeInstead = (label: 'Type instead', onPressed: onTypeInstead);
    final Widget? child = switch (status) {
      ScanIdle() => null,
      ScanAnalyzing(:final photo) => _AnalyzingCard(photo: photo),
      ScanSucceeded(:final added) => _Notice(
        icon: Icons.check_circle_outline,
        message: switch (added) {
          0 => 'Everything in that photo is already on your list.',
          1 => 'Added 1 ingredient from your photo. Check it below.',
          _ => 'Added $added ingredients from your photo. Check them below.',
        },
      ),
      ScanFoundNothing() => _Notice(
        icon: Icons.search_off,
        message:
            'We couldn’t spot any ingredients in that photo. Try a closer, '
            'brighter shot.',
        actions: [typeInstead],
      ),
      ScanPickFailed(:final source, :final error) => _Notice(
        icon: Icons.no_photography_outlined,
        isError: true,
        message: _pickFailedMessage(source, error),
        actions: [typeInstead],
      ),
      ScanFailed(:final error) => _Notice(
        icon: error == IngredientDetectionError.offline
            ? Icons.wifi_off
            : Icons.error_outline,
        isError: true,
        message: _detectionFailedMessage(error),
        actions: [
          if (error.isRetryable) (label: 'Try again', onPressed: onRetry),
          typeInstead,
        ],
      ),
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 16), child: child);
  }

  static String _pickFailedMessage(
    PhotoSource source,
    PhotoPickerError error,
  ) => switch ((source, error)) {
    (PhotoSource.camera, PhotoPickerError.accessDenied) =>
      'SnapChef can’t use your camera. Allow camera access in Settings, or '
          'choose a photo or type your ingredients instead.',
    (PhotoSource.gallery, PhotoPickerError.accessDenied) =>
      'SnapChef can’t open your photos. Allow photo access in Settings, or '
          'take a photo or type your ingredients instead.',
    (_, PhotoPickerError.noCamera) =>
      'This device doesn’t have a camera. Choose a photo or type your '
          'ingredients instead.',
    (_, PhotoPickerError.failed) =>
      'We couldn’t open that photo. Try another one, or type your '
          'ingredients instead.',
  };

  static String _detectionFailedMessage(IngredientDetectionError error) =>
      switch (error) {
        IngredientDetectionError.offline =>
          'You’re offline. Check your connection and try again.',
        IngredientDetectionError.timeout =>
          'Analyzing your photo took too long. Please try again.',
        IngredientDetectionError.busy =>
          'Ingredient scanning is busy right now. Wait a minute and try again.',
        IngredientDetectionError.invalidPhoto =>
          'We can’t read that photo. Try a different one.',
        IngredientDetectionError.signedOut =>
          'Your session has expired. Log out and back in to scan photos.',
        IngredientDetectionError.failed =>
          'We couldn’t analyze that photo. Please try again.',
      };
}

class _AnalyzingCard extends StatelessWidget {
  const _AnalyzingCard({required this.photo});

  final Photo photo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                photo.bytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                cacheWidth: 168,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => SizedBox.square(
                  dimension: 56,
                  child: Icon(
                    Icons.image_outlined,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Finding ingredients…'),
                  SizedBox(height: 8),
                  LinearProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An outcome message with optional actions; red when something went wrong.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.message,
    this.isError = false,
    this.actions = const [],
  });

  final IconData icon;
  final String message;
  final bool isError;
  final List<({String label, VoidCallback onPressed})> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = isError
        ? colors.errorContainer
        : colors.surfaceContainerHighest;
    final foreground = isError ? colors.onErrorContainer : colors.onSurface;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isError ? foreground : colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: TextStyle(color: foreground)),
                  if (actions.isEmpty)
                    const SizedBox(height: 8)
                  else
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final action in actions)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: foreground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            onPressed: action.onPressed,
                            child: Text(action.label),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name});

  final String name;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  // Starts fully selected so typing replaces the old name.
  late final _name = TextEditingController(
    text: widget.name,
  )..selection = TextSelection(baseOffset: 0, extentOffset: widget.name.length);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_name.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename ingredient'),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
