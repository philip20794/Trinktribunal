/// Android can report zero width before sending its first viewport metrics.
/// Keep layout arithmetic valid while the native view is being attached/resized.
double homeCardWidth(double availableWidth) {
  final content = availableWidth.clamp(40.0, 1056.0) - 40.0;
  return availableWidth >= 840 ? (content - 12.0) / 2 : content;
}
