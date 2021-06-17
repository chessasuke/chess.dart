import 'package:chessjs/chessjs.dart';

void main() {
  Chess chess = Chess();
  print(chess.ascii);
  while (!chess.gameOver) {
    print('position: ' + chess.fen);
    print(chess.ascii);
    var moves = chess.moves();
    moves.shuffle();
    var move = moves[0];
    chess.move(move);
    print('move: ' + move);
  }

  print(chess.ascii);
  if (chess.inCheckmate) {
    print("Checkmate");
  }
  if (chess.inStalemate) {
    print("Stalemate");
  }
  if (chess.inDraw) {
    print("Draw");
  }
  if (chess.insufficientMaterial) {
    print("Insufficient Material");
  }
}
