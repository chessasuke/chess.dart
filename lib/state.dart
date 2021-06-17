import 'color.dart';
import 'move.dart';
import 'constants.dart';

class State {
  final Move move;
  final ColorMap<int> kings;
  final Color turn;
  final ColorMap<int> castling;
  final int epSquare;
  final int halfMoves;
  final int moveNumber;
  const State(this.move, this.kings, this.turn, this.castling, this.epSquare,
      this.halfMoves, this.moveNumber);
}
