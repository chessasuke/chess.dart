import 'constants.dart';

class Piece {
  PieceType type;
  final Color color;
  Piece(this.type, this.color);
}

class PieceType {
  final int shift;
  final String name;
  const PieceType._internal(this.shift, this.name);

  static const PieceType PAWN = const PieceType._internal(0, 'p');
  static const PieceType KNIGHT = const PieceType._internal(1, 'n');
  static const PieceType BISHOP = const PieceType._internal(2, 'b');
  static const PieceType ROOK = const PieceType._internal(3, 'r');
  static const PieceType QUEEN = const PieceType._internal(4, 'q');
  static const PieceType KING = const PieceType._internal(5, 'k');

  int get hashCode => shift;
  String toString() => name;
  String toLowerCase() => name;
  String toUpperCase() => name.toUpperCase();
}
