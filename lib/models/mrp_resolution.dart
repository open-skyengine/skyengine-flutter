class MrpResolution {
  final int width;
  final int height;

  const MrpResolution(this.width, this.height);

  String get label => '${width}x$height';

  static MrpResolution? tryParse(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final match = RegExp(
      r'^(\d{2,5})\s*[xX]\s*(\d{2,5})$',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }
    final width = int.tryParse(match.group(1)!);
    final height = int.tryParse(match.group(2)!);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return MrpResolution(width, height);
  }

  @override
  bool operator ==(Object other) {
    return other is MrpResolution &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}

const kDefaultMrpResolution = MrpResolution(240, 320);

const kCommonMrpResolutions = [
  MrpResolution(128, 160),
  MrpResolution(176, 220),
  kDefaultMrpResolution,
  MrpResolution(240, 400),
  MrpResolution(320, 240),
  MrpResolution(320, 480),
  MrpResolution(480, 800),
];
