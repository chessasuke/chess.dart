import 'constants.dart';
import 'pieces.dart';
import 'utils.dart';

class Move {
  const Move({
    required this.color,
    required this.from,
    required this.to,
    required this.flags,
    required this.piece,
    this.captured,
    this.promotion,
  });

  final Color color;
  final int from;
  final int to;
  final int flags;
  final PieceType piece;
  final PieceType? captured;
  final PieceType? promotion;

  String get fromAlgebraic {
    return algebraic(from);
  }

  String get toAlgebraic {
    return algebraic(to);
  }
}
