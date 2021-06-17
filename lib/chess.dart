//part of 'chessjs.dart';

import 'move.dart';
import 'color.dart';
import 'pieces.dart';
import 'state.dart';
import 'constants.dart';
import 'utils.dart';

class Chess {
  static final Map<Color, List> ROOKS = {
    WHITE: [
      {'square': SQUARES_A1, 'flag': BITS_QSIDE_CASTLE},
      {'square': SQUARES_H1, 'flag': BITS_KSIDE_CASTLE}
    ],
    BLACK: [
      {'square': SQUARES_A8, 'flag': BITS_QSIDE_CASTLE},
      {'square': SQUARES_H8, 'flag': BITS_KSIDE_CASTLE}
    ]
  };

  // Instance Variables
  List<Piece?> board = List.filled(128, null, growable: false);
  ColorMap<int> kings = ColorMap(EMPTY);
  Color turn = WHITE;
  ColorMap<int> castling = ColorMap(0);
  int epSquare = EMPTY;
  int halfMoves = 0;
  int moveNumber = 1;
  List<State> history = [];
  Map header = {};

  /// Default constructor starts game from the standard chess starting position
  Chess() {
    load(DEFAULT_POSITION);
  }

  /// Custom constructor to start game from a FEN
  Chess.fromFEN(String fen) {
    load(fen);
  }

  /// Deep copy of the current Chess instance
  Chess copy() {
    return new Chess()
      ..board = List<Piece>.from(this.board)
      ..kings = ColorMap<int>.clone(this.kings)
      ..turn = this.turn
      ..castling = ColorMap<int>.clone(this.castling)
      ..epSquare = this.epSquare
      ..halfMoves = this.halfMoves
      ..moveNumber = this.moveNumber
      ..history = List<State>.from(this.history)
      ..header = Map.from(this.header);
  }

  /// Reset all of the instance variables
  clear() {
    board = List.filled(128, null, growable: false);
    kings = ColorMap(EMPTY);
    turn = WHITE;
    castling = ColorMap(0);
    epSquare = EMPTY;
    halfMoves = 0;
    moveNumber = 1;
    history = [];
    header = {};
    updateSetup(generateFen());
  }

  /// Go back to the chess starting position
  reset() {
    load(DEFAULT_POSITION);
  }

  /// Load a position from a FEN String
  bool load(String fen) {
    /// get FEN fields
    List tokens = fen.split(RegExp(r"\s+"));

    /// position is the Piece placement
    String position = tokens[0];
    int square = 0;
//    String valid = SYMBOLS + '12345678/';

    /// Check if FEN is valid
    Map validMap = validateFen(fen);
    if (!validMap["valid"]) {
      print(validMap["error"]);
      return false;
    }

    clear();

    for (int i = 0; i < position.length; i++) {
      String piece = position[i];

      if (piece == '/') {
        square += 8;
      } else if (isDigit(piece)) {
        square += int.parse(piece);
      } else {
        /// Upper case means WHITE, otherwise BLACK
        Color color = (piece == piece.toUpperCase()) ? WHITE : BLACK;

        /// Get piece type
        PieceType type = PIECE_TYPES[piece.toLowerCase()]!;

        put(Piece(type, color), algebraic(square));
        square++;
      }
    }

    /// Get turn to play
    if (tokens[1] == 'w') {
      turn = WHITE;
    } else {
      assert(tokens[1] == 'b');
      turn = BLACK;
    }

    /// Get castling availability
    if (tokens[2].indexOf('K') > -1) {
      castling[WHITE] |= BITS_KSIDE_CASTLE;
    }
    if (tokens[2].indexOf('Q') > -1) {
      castling[WHITE] |= BITS_QSIDE_CASTLE;
    }
    if (tokens[2].indexOf('k') > -1) {
      castling[BLACK] |= BITS_KSIDE_CASTLE;
    }
    if (tokens[2].indexOf('q') > -1) {
      castling[BLACK] |= BITS_QSIDE_CASTLE;
    }

    epSquare = (tokens[3] == '-') ? EMPTY : SQUARES[tokens[3]];
    halfMoves = int.parse(tokens[4]);
    moveNumber = int.parse(tokens[5]);

    updateSetup(generateFen());

    return true;
  }

  /// Check the formatting of a FEN String is correct
  /// Returns a Map with keys valid, error_number, and error
  static Map validateFen(fen) {
    Map errors = {
      0: 'No errors.',
      1: 'FEN string must contain six space-delimited fields.',
      2: '6th field (move number) must be a positive integer.',
      3: '5th field (half move counter) must be a non-negative integer.',
      4: '4th field (en-passant square) is invalid.',
      5: '3rd field (castling availability) is invalid.',
      6: '2nd field (side to move) is invalid.',
      7: '1st field (piece positions) does not contain 8 \'/\'-delimited rows.',
      8: '1st field (piece positions) is invalid [consecutive numbers].',
      9: '1st field (piece positions) is invalid [invalid piece].',
      10: '1st field (piece positions) is invalid [row too large].',
    };

    /// Fields of the FEN are separated by spaces
    /// retrieve fields form the FEN -> must be 6 of them
    /// Wikipedia:
    /// A FEN record contains six fields.
    /// The separator between fields is a space
    List tokens = fen.split(RegExp(r"\s+"));
    if (tokens.length != 6) {
      return {'valid': false, 'error_number': 1, 'error': errors[1]};
    }

    /// the last Field of FEN should be the number of moves
    /// this should be a positive integer since starts at 1
    /// Wikipedia: "Fullmove number: The number of the full move.
    /// It starts at 1, and is incremented after Black's move."
    int? temp = int.tryParse(tokens[5]);
    if (temp != null) {
      if (temp <= 0) {
        return {'valid': false, 'error_number': 2, 'error': errors[2]};
      }
    } else {
      return {'valid': false, 'error_number': 2, 'error': errors[2]};
    }

    /// The second to last field is the counter
    /// of moves for the 50 moves draw rule
    temp = int.tryParse(tokens[4]);
    if (temp != null) {
      if (temp < 0) {
        return {'valid': false, 'error_number': 3, 'error': errors[3]};
      }
    } else {
      return {'valid': false, 'error_number': 3, 'error': errors[3]};
    }

    /// Wikipedia: En passant target square in algebraic notation.
    /// If there's no en passant target square, this is "-".
    /// If a pawn has just made a two-square move,
    /// this is the position "behind" the pawn.
    /// This is recorded regardless of whether there is a pawn
    /// in position to make an en passant capture.
    RegExp checkEnPassant = new RegExp(r"^(-|[abcdefgh][36])$");
    if (checkEnPassant.firstMatch(tokens[3]) == null) {
      return {'valid': false, 'error_number': 4, 'error': errors[4]};
    }

    /// Wikipedia:
    /// Castling availability. If neither side can castle, this is "-".
    /// Otherwise, this has one or more letters: "K" (White can castle kingside),
    /// "Q" (White can castle queenside), "k" (Black can castle kingside),
    /// and/or "q" (Black can castle queenside).
    /// A move that temporarily prevents castling does not negate this notation.
    RegExp checkCastling = new RegExp(r"^(KQ?k?q?|Qk?q?|kq?|q|-)$");
    if (checkCastling.firstMatch(tokens[2]) == null) {
      return {'valid': false, 'error_number': 5, 'error': errors[5]};
    }

    /// Wikipedia:
    /// Active color. "w" means White moves next,
    /// "b" means Black moves next.
    RegExp moveTurn = new RegExp(r"^(w|b)$");
    if (moveTurn.firstMatch(tokens[1]) == null) {
      return {'valid': false, 'error_number': 6, 'error': errors[6]};
    }

    /// Wikipedia:
    /// Piece placement (from White's perspective).
    /// Each rank is described, starting with rank 8 and ending with rank 1
    /// within each rank, the contents of each square are described from file
    /// "a" through file "h". Using the Standard Algebraic Notation (SAN)

    /// There must be 8 rows
    List rows = tokens[0].split('/');
    if (rows.length != 8) {
      return {'valid': false, 'error_number': 7, 'error': errors[7]};
    }

    /// Check validity of rows
    for (int i = 0; i < rows.length; i++) {
      /// there should be 8 rows, increment
      /// sumFields after check each valid row
      int sumFields = 0;
      bool previousWasNumber = false;

      /// Check content of rows, there shouldn't be two successive numbers
      /// since each number is the number of empty squares between two pieces
      for (int k = 0; k < rows[i].length; k++) {
        int? temp2 = int.tryParse(rows[i][k]);

        /// if not null then is a number in the row and
        /// the previous token should not be a number
        if (temp2 != null) {
          if (previousWasNumber) {
            return {'valid': false, 'error_number': 8, 'error': errors[8]};
          }
          sumFields += temp2;
          previousWasNumber = true;
        }

        /// if it's not a number then it's a piece token check
        /// with a regular expression
        else {
          RegExp checkOM = RegExp(r"^[prnbqkPRNBQK]$");
          if (checkOM.firstMatch(rows[i][k]) == null) {
            return {'valid': false, 'error_number': 9, 'error': errors[9]};
          }
          sumFields += 1;
          previousWasNumber = false;
        }
      }

      if (sumFields != 8) {
        return {'valid': false, 'error_number': 10, 'error': errors[10]};
      }
    }

    /// Everything is ok
    return {'valid': true, 'error_number': 0, 'error': errors[0]};
  }

  /// Returns a FEN String representing the current position
  String generateFen() {
    int empty = 0;
    String fen = '';

    for (int i = SQUARES_A8; i <= SQUARES_H1; i++) {
      if (board[i] == null) {
        empty++;
      } else {
        if (empty > 0) {
          fen += empty.toString();
          empty = 0;
        }
        Color color = board[i]!.color;
        PieceType type = board[i]!.type;

        fen += (color == WHITE) ? type.toUpperCase() : type.toLowerCase();
      }

      if (((i + 1) & 0x88) != 0) {
        if (empty > 0) {
          fen += empty.toString();
        }

        if (i != SQUARES_H1) {
          fen += '/';
        }

        empty = 0;
        i += 8;
      }
    }

    String cflags = '';
    if ((castling[WHITE] & BITS_KSIDE_CASTLE) != 0) {
      cflags += 'K';
    }
    if ((castling[WHITE] & BITS_QSIDE_CASTLE) != 0) {
      cflags += 'Q';
    }
    if ((castling[BLACK] & BITS_KSIDE_CASTLE) != 0) {
      cflags += 'k';
    }
    if ((castling[BLACK] & BITS_QSIDE_CASTLE) != 0) {
      cflags += 'q';
    }

    /* do we have an empty castling flag? */
    if (cflags == "") {
      cflags = '-';
    }
    String epflags = (epSquare == EMPTY) ? '-' : algebraic(epSquare);
    String turnStr = (turn == Color.WHITE) ? 'w' : 'b';

    return [fen, turnStr, cflags, epflags, halfMoves, moveNumber].join(' ');
  }

  /// Updates [header] with the List of args and returns it
  Map setHeader(args) {
    for (int i = 0; i < args.length; i += 2) {
      if (args[i] is String && args[i + 1] is String) {
        header[args[i]] = args[i + 1];
      }
    }
    return header;
  }

  /// called when the initial board setup is changed with put() or remove().
  /// modifies the SetUp and FEN properties of the header object.  if the FEN is
  /// equal to the default position, the SetUp and FEN are deleted
  /// the setup is only updated if history.length is zero, ie moves haven't been
  /// made.
  void updateSetup(String fen) {
    if (history.length > 0) return;

    if (fen != DEFAULT_POSITION) {
      header['SetUp'] = '1';
      header['FEN'] = fen;
    } else {
      header.remove('SetUp');
      header.remove('FEN');
    }
  }

  /// Returns the piece at the square in question or null
  /// if there is none
  Piece? get(String square) {
    return board[SQUARES[square]];
  }

  /// Put [piece] on [square]
  bool put(Piece piece, String square) {
    /* check for piece */
    if (SYMBOLS.indexOf(piece.type.toLowerCase()) == -1) {
      return false;
    }

    /* check for valid square */
    if (!(SQUARES.containsKey(square))) {
      return false;
    }

    int sq = SQUARES[square];
    board[sq] = piece;
    if (piece.type == KING) {
      kings[piece.color] = sq;
    }

    updateSetup(generateFen());

    return true;
  }

  /// Removes a piece from a square and returns it,
  /// or null if none is present
  Piece? remove(String square) {
    Piece? piece = get(square);
    board[SQUARES[square]] = null;
    if (piece != null && piece.type == KING) {
      kings[piece.color] = EMPTY;
    }
    updateSetup(generateFen());
    return piece;
  }

  Move buildMove(List<Piece?> board, int from, int to, int flags,
      [PieceType? promotion]) {
    if (promotion != null) {
      flags |= BITS_PROMOTION;
    }
    PieceType? captured;
    Piece? toPiece = board[to];
    if (toPiece != null) {
      captured = toPiece.type;
    } else if ((flags & BITS_EP_CAPTURE) != 0) {
      captured = PAWN;
    }
    return Move(
        color: turn,
        from: from,
        to: to,
        flags: flags,
        piece: board[from]!.type,
        captured: captured,
        promotion: promotion);
  }

  /// Generate moves for a determined piece
  /// Receives the square where the piece is on,
  /// in case there is none piece returns empty []
  List<Move> generateMovesForPiece(
      {required String fromSquare, bool legal = true}) {
    List<Move> moves = [];
    if (get(fromSquare) == null) return moves;
    moves = generateMoves({'legal': legal});
    if (moves.isNotEmpty) {
      moves.removeWhere((element) => element.fromAlgebraic != fromSquare);
    }
    return moves;
  }

  List<Move> generateMoves([Map? options]) {
    addMove(List<Piece?> board, List<Move> moves, from, to, flags) {
      /* if pawn promotion */
      if (board[from]!.type == PAWN &&
          (rank(to) == RANK_8 || rank(to) == RANK_1)) {
        List pieces = [QUEEN, ROOK, BISHOP, KNIGHT];
        for (var i = 0, len = pieces.length; i < len; i++) {
          moves.add(buildMove(board, from, to, flags, pieces[i]));
        }
      } else {
        moves.add(buildMove(board, from, to, flags));
      }
    }

    List<Move> moves = [];
    Color us = turn;
    Color them = swapColor(us);
    ColorMap<int> secondRank = ColorMap(0);
    secondRank[BLACK] = RANK_7;
    secondRank[WHITE] = RANK_2;

    var firstSq = SQUARES_A8;
    var lastSq = SQUARES_H1;
    bool singleSquare = false;

    /* do we want legal moves? */
    var legal = (options != null && options.containsKey('legal'))
        ? options['legal']
        : true;

    /* are we generating moves for a single square? */
    if (options != null && options.containsKey('square')) {
      if (SQUARES.containsKey(options['square'])) {
        firstSq = lastSq = SQUARES[options['square']];
        singleSquare = true;
      } else {
        /* invalid square */
        return [];
      }
    }

    for (int i = firstSq; i <= lastSq; i++) {
      /* did we run off the end of the board */
      if ((i & 0x88) != 0) {
        i += 7;
        continue;
      }

      Piece? piece = board[i];
      if (piece == null || piece.color != us) {
        continue;
      }

      if (piece.type == PAWN) {
        /* single square, non-capturing */
        int square = i + PAWN_OFFSETS[us]![0];
        if (board[square] == null) {
          addMove(board, moves, i, square, BITS_NORMAL);

          /* double square */
          int square2 = i + PAWN_OFFSETS[us]![1];
          if (secondRank[us] == rank(i) && board[square2] == null) {
            addMove(board, moves, i, square2, BITS_BIG_PAWN);
          }
        }

        /* pawn captures */
        for (int j = 2; j < 4; j++) {
          int square = i + PAWN_OFFSETS[us]![j];
          if ((square & 0x88) != 0) continue;

          if (board[square] != null) {
            if (board[square]!.color == them) {
              addMove(board, moves, i, square, BITS_CAPTURE);
            } else if (square == epSquare) {
              addMove(board, moves, i, epSquare, BITS_EP_CAPTURE);
            }
          } else if (square == epSquare) {
            addMove(board, moves, i, epSquare, BITS_EP_CAPTURE);
          }
        }
      } else {
        for (int j = 0, len = PIECE_OFFSETS[piece.type]!.length; j < len; j++) {
          int offset = PIECE_OFFSETS[piece.type]![j];
          int square = i;

          while (true) {
            square += offset;
            if ((square & 0x88) != 0) break;

            if (board[square] == null) {
              addMove(board, moves, i, square, BITS_NORMAL);
            } else {
              if (board[square]!.color == us) {
                break;
              }
              addMove(board, moves, i, square, BITS_CAPTURE);
              break;
            }

            /* break, if knight or king */
            if (piece.type == KNIGHT || piece.type == KING) break;
          }
        }
      }
    }

    // check for castling if: a) we're generating all moves, or b) we're doing
    // single square move generation on the king's square
    if ((!singleSquare) || lastSq == kings[us]) {
      /* king-side castling */
      if ((castling[us] & BITS_KSIDE_CASTLE) != 0) {
        var castlingFrom = kings[us];
        var castlingTo = castlingFrom + 2;

        if (board[castlingFrom + 1] == null &&
            board[castlingTo] == null &&
            !attacked(them, kings[us]) &&
            !attacked(them, castlingFrom + 1) &&
            !attacked(them, castlingTo)) {
          addMove(board, moves, kings[us], castlingTo, BITS_KSIDE_CASTLE);
        }
      }

      /* queen-side castling */
      if ((castling[us] & BITS_QSIDE_CASTLE) != 0) {
        var castlingFrom = kings[us];
        var castlingTo = castlingFrom - 2;

        if (board[castlingFrom - 1] == null &&
            board[castlingFrom - 2] == null &&
            board[castlingFrom - 3] == null &&
            !attacked(them, kings[us]) &&
            !attacked(them, castlingFrom - 1) &&
            !attacked(them, castlingTo)) {
          addMove(board, moves, kings[us], castlingTo, BITS_QSIDE_CASTLE);
        }
      }
    }

    /* return all pseudo-legal moves (this includes moves that allow the king
     * to be captured)
     */
    if (!legal) {
      return moves;
    }

    /* filter out illegal moves */
    List<Move> legalMoves = [];
    for (int i = 0, len = moves.length; i < len; i++) {
      makeMove(moves[i]);
      if (!kingAttacked(us)) {
        legalMoves.add(moves[i]);
      }
      undoMove();
    }

    return legalMoves;
  }

  /// Convert a move from 0x88 coordinates to Standard Algebraic Notation(SAN)
  String moveToSan(Move move) {
    String output = '';
    int flags = move.flags;
    if ((flags & BITS_KSIDE_CASTLE) != 0) {
      output = 'O-O';
    } else if ((flags & BITS_QSIDE_CASTLE) != 0) {
      output = 'O-O-O';
    } else {
      var disambiguator = getDisambiguator(move);

      if (move.piece != PAWN) {
        output += move.piece.toUpperCase() + disambiguator;
      }

      if ((flags & (BITS_CAPTURE | BITS_EP_CAPTURE)) != 0) {
        if (move.piece == PAWN) {
          output += move.fromAlgebraic[0];
        }
        output += 'x';
      }

      output += move.toAlgebraic;

      if ((flags & BITS_PROMOTION) != 0) {
        output += '=' + move.promotion!.toUpperCase();
      }
    }

    makeMove(move);
    if (inCheck) {
      if (inCheckmate) {
        output += '#';
      } else {
        output += '+';
      }
    }
    undoMove();

    return output;
  }

  bool attacked(Color color, int square) {
    for (int i = SQUARES_A8; i <= SQUARES_H1; i++) {
      /* did we run off the end of the board */
      if ((i & 0x88) != 0) {
        i += 7;
        continue;
      }

      /* if empty square or wrong color */
      Piece? piece = board[i];
      if (piece == null || piece.color != color) continue;

      var difference = i - square;
      var index = difference + 119;
      PieceType type = piece.type;

      if ((ATTACKS[index] & (1 << type.shift)) != 0) {
        if (type == PAWN) {
          if (difference > 0) {
            if (color == WHITE) return true;
          } else {
            if (color == BLACK) return true;
          }
          continue;
        }

        /* if the piece is a knight or a king */
        if (type == KNIGHT || type == KING) return true;

        int offset = RAYS[index];
        int j = i + offset;

        var blocked = false;
        while (j != square) {
          if (board[j] != null) {
            blocked = true;
            break;
          }
          j += offset;
        }

        if (!blocked) return true;
      }
    }

    return false;
  }

  bool kingAttacked(Color color) {
    return attacked(swapColor(color), kings[color]);
  }

  bool get inCheck {
    return kingAttacked(turn);
  }

  bool get inCheckmate {
    return inCheck && generateMoves().length == 0;
  }

  bool get inStalemate {
    return !inCheck && generateMoves().length == 0;
  }

  bool get insufficientMaterial {
    Map pieces = {};
    List<int> bishops = [];
    int numPieces = 0;
    int sqColor = 0;

    for (int i = SQUARES_A8; i <= SQUARES_H1; i++) {
      sqColor = (sqColor + 1) % 2;
      if ((i & 0x88) != 0) {
        i += 7;
        continue;
      }

      Piece? piece = board[i];
      if (piece != null) {
        pieces[piece.type] =
            (pieces.containsKey(piece.type)) ? pieces[piece.type] + 1 : 1;
        if (piece.type == BISHOP) {
          bishops.add(sqColor);
        }
        numPieces++;
      }
    }

    /* k vs. k */
    if (numPieces == 2) {
      return true;
    } /* k vs. kn .... or .... k vs. kb */
    else if (numPieces == 3 && (pieces[BISHOP] == 1 || pieces[KNIGHT] == 1)) {
      return true;
    } /* kb vs. kb where any number of bishops are all on the same color */
    else if (pieces.containsKey(BISHOP) && numPieces == (pieces[BISHOP] + 2)) {
      int sum = 0;
      int len = bishops.length;
      for (int i = 0; i < len; i++) {
        sum += bishops[i];
      }
      if (sum == 0 || sum == len) {
        return true;
      }
    }

    return false;
  }

  bool get inThreefoldRepetition {
    /* TODO: while this function is fine for casual use, a better
     * implementation would use a Zobrist key (instead of FEN). the
     * Zobrist key would be maintained in the make_move/undo_move functions,
     * avoiding the costly that we do below.
     */
    List moves = [];
    Map positions = {};
    bool repetition = false;

    while (true) {
      var move = undoMove();
      if (move == null) {
        break;
      }
      moves.add(move);
    }

    while (true) {
      /* remove the last two fields in the FEN string, they're not needed
       * when checking for draw by rep */
      var fen = generateFen().split(' ').sublist(0, 4).join(' ');

      /* has the position occurred three or move times */
      positions[fen] = (positions.containsKey(fen)) ? positions[fen] + 1 : 1;
      if (positions[fen] >= 3) {
        repetition = true;
      }

      if (moves.length == 0) {
        break;
      }
      makeMove(moves.removeLast());
    }

    return repetition;
  }

  void push(Move move) {
    history.add(State(move, ColorMap.clone(kings), turn,
        ColorMap.clone(castling), epSquare, halfMoves, moveNumber));
  }

  makeMove(Move move) {
    Color us = turn;
    Color them = swapColor(us);
    push(move);

    board[move.to] = board[move.from];
    board[move.from] = null;

    /* if ep capture, remove the captured pawn */
    if ((move.flags & BITS_EP_CAPTURE) != 0) {
      if (turn == BLACK) {
        board[move.to - 16] = null;
      } else {
        board[move.to + 16] = null;
      }
    }

    /* if pawn promotion, replace with new piece */
    if ((move.flags & BITS_PROMOTION) != 0) {
      board[move.to] = Piece(move.promotion!, us);
    }

    /* if we moved the king */
    if (board[move.to]!.type == KING) {
      kings[board[move.to]!.color] = move.to;

      /* if we castled, move the rook next to the king */
      if ((move.flags & BITS_KSIDE_CASTLE) != 0) {
        int castlingTo = move.to - 1;
        int castlingFrom = move.to + 1;
        board[castlingTo] = board[castlingFrom];
        board[castlingFrom] = null;
      } else if ((move.flags & BITS_QSIDE_CASTLE) != 0) {
        int castlingTo = move.to + 1;
        int castlingFrom = move.to - 2;
        board[castlingTo] = board[castlingFrom];
        board[castlingFrom] = null;
      }

      /* turn off castling */
      castling[us] = 0;
    }

    /* turn off castling if we move a rook */
    if (castling[us] != 0) {
      for (int i = 0; i < ROOKS[us]!.length; i++) {
        if (move.from == ROOKS[us]![i]['square'] &&
            ((castling[us] & ROOKS[us]![i]['flag']) != 0)) {
          castling[us] ^= ROOKS[us]![i]['flag'];
          break;
        }
      }
    }

    /* turn off castling if we capture a rook */
    if (castling[them] != 0) {
      for (int i = 0, len = ROOKS[them]!.length; i < len; i++) {
        if (move.to == ROOKS[them]![i]['square'] &&
            ((castling[them] & ROOKS[them]![i]['flag']) != 0)) {
          castling[them] ^= ROOKS[them]![i]['flag'];
          break;
        }
      }
    }

    /* if big pawn move, update the en passant square */
    if ((move.flags & BITS_BIG_PAWN) != 0) {
      if (turn == BLACK) {
        epSquare = move.to - 16;
      } else {
        epSquare = move.to + 16;
      }
    } else {
      epSquare = EMPTY;
    }

    /* reset the 50 move counter if a pawn is moved or a piece is captured */
    if (move.piece == PAWN) {
      halfMoves = 0;
    } else if ((move.flags & (BITS_CAPTURE | BITS_EP_CAPTURE)) != 0) {
      halfMoves = 0;
    } else {
      halfMoves++;
    }

    if (turn == BLACK) {
      moveNumber++;
    }
    turn = swapColor(turn);
  }

  /// Undoes a move and returns it, or null if move history is empty
  Move? undoMove() {
    if (history.isEmpty) {
      return null;
    }
    State old = history.removeLast();

    Move move = old.move;
    kings = old.kings;
    turn = old.turn;
    castling = old.castling;
    epSquare = old.epSquare;
    halfMoves = old.halfMoves;
    moveNumber = old.moveNumber;

    Color us = turn;
    Color them = swapColor(turn);

    board[move.from] = board[move.to];
    board[move.from]!.type = move.piece; // to undo any promotions
    board[move.to] = null;

    if ((move.flags & BITS_CAPTURE) != 0) {
      board[move.to] = Piece(move.captured!, them);
    } else if ((move.flags & BITS_EP_CAPTURE) != 0) {
      var index;
      if (us == BLACK) {
        index = move.to - 16;
      } else {
        index = move.to + 16;
      }
      board[index] = Piece(PAWN, them);
    }

    if ((move.flags & (BITS_KSIDE_CASTLE | BITS_QSIDE_CASTLE)) != 0) {
      var castlingTo, castlingFrom;
      if ((move.flags & BITS_KSIDE_CASTLE) != 0) {
        castlingTo = move.to + 1;
        castlingFrom = move.to - 1;
      } else if ((move.flags & BITS_QSIDE_CASTLE) != 0) {
        castlingTo = move.to - 2;
        castlingFrom = move.to + 1;
      }

      board[castlingTo] = board[castlingFrom];
      board[castlingFrom] = null;
    }

    return move;
  }

  /* this function is used to uniquely identify ambiguous moves */
  getDisambiguator(Move move) {
    List<Move> moves = generateMoves();

    var from = move.from;
    var to = move.to;
    var piece = move.piece;

    var ambiguities = 0;
    var sameRank = 0;
    var sameFile = 0;

    for (int i = 0, len = moves.length; i < len; i++) {
      var ambigFrom = moves[i].from;
      var ambigTo = moves[i].to;
      var ambigPiece = moves[i].piece;

      /* if a move of the same piece type ends on the same to square, we'll
       * need to add a disambiguator to the algebraic notation
       */
      if (piece == ambigPiece && from != ambigFrom && to == ambigTo) {
        ambiguities++;

        if (rank(from) == rank(ambigFrom)) {
          sameRank++;
        }

        if (file(from) == file(ambigFrom)) {
          sameFile++;
        }
      }
    }

    if (ambiguities > 0) {
      /* if there exists a similar moving piece on the same rank and file as
       * the move in question, use the square as the disambiguator
       */
      if (sameRank > 0 && sameFile > 0) {
        return algebraic(from);
      } /* if the moving piece rests on the same file, use the rank symbol as the
       * disambiguator
       */
      else if (sameFile > 0) {
        return algebraic(from)[1];
      } /* else use the file symbol */
      else {
        return algebraic(from)[0];
      }
    }

    return '';
  }

  /// Returns a String representation of the current position
  /// complete with ascii art
  String get ascii {
    String s = '   +------------------------+\n';
    for (var i = SQUARES_A8; i <= SQUARES_H1; i++) {
      /* display the rank */
      if (file(i) == 0) {
        s += ' ' + '87654321'[rank(i)] + ' |';
      }

      /* empty piece */
      if (board[i] == null) {
        s += ' ' + ' . ' + ' ';
      } else {
        PieceType type = board[i]!.type;
        Color color = board[i]!.color;
        var symbol = (color == WHITE) ? type.toUpperCase() : type.toLowerCase();
        s += ' ' + symbol + ' ';
      }

      if (((i + 1) & 0x88) != 0) {
        s += '|\n';
        i += 8;
      }
    }
    s += '   +------------------------+\n';
    s += '     a  b  c  d  e  f  g  h\n';

    return s;
  }

  /// pretty = external move object
  Map makePretty(Move uglyMove) {
    Map map = {};
    map['san'] = moveToSan(uglyMove);
    map['to'] = uglyMove.toAlgebraic;
    map['from'] = uglyMove.fromAlgebraic;
    map['captured'] = uglyMove.captured;
    map['color'] = uglyMove.color;

    var flags = '';
    for (var flag in BITS.keys) {
      if ((BITS[flag]! & uglyMove.flags) != 0) {
        flags += FLAGS[flag]!;
      }
    }
    map['flags'] = flags;

    return map;
  }

  //Public APIs

  ///  Returns a list of legals moves from the current position.
  ///  The function takes an optional parameter which controls the
  ///  single-square move generation and verbosity.
  ///
  ///  The piece, captured, and promotion fields contain the lowercase
  ///  representation of the applicable piece.
  ///
  ///  The flags field in verbose mode may contain one or more of the following values:
  ///
  ///  'n' - a non-capture
  ///  'b' - a pawn push of two squares
  ///  'e' - an en passant capture
  ///  'c' - a standard capture
  ///  'p' - a promotion
  ///  'k' - kingside castling
  ///  'q' - queenside castling
  ///  A flag of 'pc' would mean that a pawn captured a piece on the 8th rank and promoted.
  ///
  ///  If "asObjects" is set to true in the options Map, then it returns a List<Move>
  List moves([Map? options]) {
    /* The internal representation of a chess move is in 0x88 format, and
       * not meant to be human-readable.  The code below converts the 0x88
       * square coordinates to algebraic coordinates.  It also prunes an
       * unnecessary move keys resulting from a verbose call.
       */

    List<Move> uglyMoves = generateMoves(options);
    if (options != null &&
        options.containsKey('asObjects') &&
        options['asObjects'] == true) {
      return uglyMoves;
    }
    List moves = [];

    for (int i = 0, len = uglyMoves.length; i < len; i++) {
      /* does the user want a full move object (most likely not), or just
         * SAN
         */
      if (options != null &&
          options.containsKey('verbose') &&
          options['verbose'] == true) {
        moves.add(makePretty(uglyMoves[i]));
      } else {
        moves.add(moveToSan(uglyMoves[i]));
      }
    }

    return moves;
  }

  bool get inDraw {
    return halfMoves >= 100 ||
        inStalemate ||
        insufficientMaterial ||
        inThreefoldRepetition;
  }

  bool get gameOver {
    return inDraw || inCheckmate;
  }

  String get fen {
    return generateFen();
  }

  /// return the san string representation of each move in history. Each string corresponds to one move.
  List<String> sanMoves() {
    /* pop all of history onto reversed_history */
    List<Move> reversedHistory = [];
    while (history.length > 0) {
      reversedHistory.add(undoMove()!);
    }

    List<String> moves = [];
    String moveString = '';
    int pgnMoveNumber = 1;

    /* build the list of moves.  a move_string looks like: "3. e3 e6" */
    while (reversedHistory.length > 0) {
      Move? move = reversedHistory.removeLast();

      /* if the position started with black to move, start PGN with 1. ... */
      if (pgnMoveNumber == 1 && move.color == BLACK) {
        moveString = '1. ...';
        pgnMoveNumber++;
      } else if (move.color == WHITE) {
        /* store the previous generated move_string if we have one */
        if (moveString.length != 0) {
          moves.add(moveString);
        }
        moveString = pgnMoveNumber.toString() + '.';
        pgnMoveNumber++;
      }

      moveString = moveString + ' ' + moveToSan(move);
      makeMove(move);
    }

    /* are there any other leftover moves? */
    if (moveString.length != 0) {
      moves.add(moveString);
    }

    /* is there a result? */
    if (header['Result'] != null) {
      moves.add(header['Result']);
    }

    return moves;
  }

  /// Return the PGN representation of the game thus far
  pgn([Map? options]) {
    /* using the specification from http://www.chessclub.com/help/PGN-spec
       * example for html usage: .pgn({ max_width: 72, newline_char: "<br />" })
       */
    var newline = (options != null &&
            options.containsKey("newline_char") &&
            options["newline_char"] != null)
        ? options['newline_char']
        : '\n';
    var maxWidth = (options != null &&
            options.containsKey("max_width") &&
            options["max_width"] != null)
        ? options["max_width"]
        : 0;
    var result = [];
    bool headerExists = false;

    /* add the PGN header headerrmation */
    for (var i in header.keys) {
      /* TODO: order of enumerated properties in header object is not
         * guaranteed, see ECMA-262 spec (section 12.6.4)
         */
      result.add(
          '[' + i.toString() + ' \"' + header[i].toString() + '\"]' + newline);
      headerExists = true;
    }

    if (headerExists && (history.length != 0)) {
      result.add(newline);
    }

    List<String> moves = sanMoves();

    if (maxWidth == 0) {
      return result.join('') + moves.join(' ');
    }

    /* wrap the PGN output at max_width */
    var currentWidth = 0;
    for (int i = 0; i < moves.length; i++) {
      /* if the current move will push past max_width */
      if (currentWidth + moves[i].length > maxWidth && i != 0) {
        /* don't end the line with whitespace */
        if (result[result.length - 1] == ' ') {
          result.removeLast();
        }

        result.add(newline);
        currentWidth = 0;
      } else if (i != 0) {
        result.add(' ');
        currentWidth++;
      }
      result.add(moves[i]);
      currentWidth += moves[i].length;
    }

    return result.join('');
  }

  /// Load the moves of a game stored in Portable Game Notation.
  /// [options] is an optional parameter that contains a 'newline_char'
  /// which is a string representation of a RegExp (and should not be pre-escaped)
  /// and defaults to '\r?\n').
  /// Returns [true] if the PGN was parsed successfully, otherwise [false].
  loadPgn(String pgn, [Map? options]) {
    mask(str) {
      return str.replaceAll(new RegExp(r"\\"), '\\');
    }

    /* convert a move from Standard Algebraic Notation (SAN) to 0x88
       * coordinates
      */
    moveFromSan(move) {
      var moves = generateMoves();
      for (var i = 0, len = moves.length; i < len; i++) {
        /* strip off any trailing move decorations: e.g Nf3+?! */
        if (move.replaceAll(RegExp(r"[+#?!=]+$"), '') ==
            moveToSan(moves[i]).replaceAll(RegExp(r"[+#?!=]+$"), '')) {
          return moves[i];
        }
      }
      return null;
    }

    getMoveObj(move) {
      return moveFromSan(trim(move));
    }

    /*has_keys(object) {
        bool has_keys = false;
        for (var key in object) {
          has_keys = true;
        }
        return has_keys;
      }*/

    parsePgnHeader(header, [Map? options]) {
      var newlineChar = (options != null && options.containsKey("newline_char"))
          ? options['newline_char']
          : '\r?\n';
      var headerObj = {};
      var headers = header.split(newlineChar);
      String key = '';
      String value = '';

      for (var i = 0; i < headers.length; i++) {
        RegExp keyMatch = new RegExp(r"^\[([A-Z][A-Za-z]*)\s.*\]$");
        var temp = keyMatch.firstMatch(headers[i]);
        if (temp != null) {
          key = temp[1]!;
        }
        //print(key);
        RegExp valueMatch = new RegExp(r'^\[[A-Za-z]+\s"(.*)"\]$');
        temp = valueMatch.firstMatch(headers[i]);
        if (temp != null) {
          value = temp[1]!;
        }
        //print(value);
        if (trim(key).length > 0) {
          headerObj[key] = value;
        }
      }

      return headerObj;
    }

    var newlineChar = (options != null && options.containsKey("newline_char"))
        ? options["newline_char"]
        : '\r?\n';
    //var regex = new RegExp(r'^(\[.*\]).*' + r'1\.'); //+ r"1\."); //+ mask(newline_char));

    int indexOfMoveStart = pgn.indexOf(new RegExp(newlineChar + r"1\."));

    /* get header part of the PGN file */
    String? headerString;
    if (indexOfMoveStart != -1) {
      headerString = pgn.substring(0, indexOfMoveStart).trim();
    }

    /* no info part given, begins with moves */
    if (headerString == null || headerString[0] != '[') {
      headerString = '';
    }

    reset();

    /* parse PGN header */
    var headers = parsePgnHeader(headerString, options);
    for (var key in headers.keys) {
      setHeader([key, headers[key]]);
    }

    /* delete header to get the moves */
    var ms = pgn
        .replaceAll(headerString, '')
        .replaceAll(new RegExp(mask(newlineChar)), ' ');

    /* delete comments */
    ms = ms.replaceAll(new RegExp(r"(\{[^}]+\})+?"), '');

    /* delete move numbers */
    ms = ms.replaceAll(new RegExp(r"\d+\."), '');

    /* trim and get array of moves */
    var moves = trim(ms).split(new RegExp(r"\s+"));

    /* delete empty entries */
    moves = moves.join(',').replaceAll(new RegExp(r",,+"), ',').split(',');
    var move;

    for (var halfMove = 0; halfMove < moves.length - 1; halfMove++) {
      move = getMoveObj(moves[halfMove]);

      /* move not possible! (don't clear the board to examine to show the
         * latest valid position)
         */
      if (move == null) {
        return false;
      } else {
        makeMove(move);
      }
    }

    /* examine last move */
    move = moves[moves.length - 1];
    if (POSSIBLE_RESULTS.contains(move)) {
      if (!header.containsKey("Result")) {
        setHeader(['Result', move]);
      }
    } else {
      var moveObj = getMoveObj(move);
      if (moveObj == null) {
        return false;
      } else {
        makeMove(moveObj);
      }
    }
    return true;
  }

  /// The move function can be called with in the following parameters:
  /// .move('Nxb7') where 'move' is a case-sensitive SAN string
  /// .move({ from: 'h7',
  ///      to :'h8',
  ///      promotion: 'q',
  ///      })
  ///      where the 'move' is a move object
  /// or it can be called with a Move object
  /// It returns true if the move was made, or false if it could not be.
  bool move(dynamic move) {
    Move? moveObj;
    List<Move> moves = generateMoves();

    if (move is String) {
      /* convert the move string to a move object */
      for (int i = 0; i < moves.length; i++) {
        if (move == moveToSan(moves[i])) {
          moveObj = moves[i];
          break;
        }
      }
    } else if (move is Map) {
      /* convert the pretty move object to an ugly move object */
      for (int i = 0; i < moves.length; i++) {
        if (move['from'] == moves[i].fromAlgebraic &&
            move['to'] == moves[i].toAlgebraic &&
            moves[i].promotion == null) {
          moveObj = moves[i];
          break;
        } else if (move['from'] == moves[i].fromAlgebraic &&
            move['to'] == moves[i].toAlgebraic &&
            move['promotion'] == moves[i].promotion!.name) {
          moveObj = moves[i];
          break;
        }
      }
    } else if (move is Move) {
      moveObj = move;
    }

    /* failed to find move */
    if (moveObj == null) {
      return false;
    }

    /* need to make a copy of move because we can't generate SAN after the
       * move is made
       */

    makeMove(moveObj);

    return true;
  }

  /// Takeback the last half-move, returning a move Map if successful, otherwise null.
  undo() {
    var move = undoMove();
    return (move != null) ? makePretty(move) : null;
  }

  /// Returns the color of the square ('light' or 'dark'), or null if [square] is invalid
  String? squareColor(square) {
    if (SQUARES.containsKey(square)) {
      var sq_0x88 = SQUARES[square];
      return ((rank(sq_0x88) + file(sq_0x88)) % 2 == 0) ? 'light' : 'dark';
    }

    return null;
  }

  /// Get current history of game in SAN format
  List<String> getHistorySAN() {
    List<Move> reversedHistory = [];
    List<String> moveHistory = [];
    while (history.length > 0) {
      reversedHistory.add(undoMove()!);
    }

    while (reversedHistory.length > 0) {
      Move move = reversedHistory.removeLast();
      moveHistory.add(moveToSan(move));
      makeMove(move);
    }

    return moveHistory;
  }

  /// Get current history of game with details in each move
  List<Map> getHistoryVerbose() {
    List<Move> reversedHistory = [];
    List<Map> moveHistory = [];

    while (history.length > 0) {
      reversedHistory.add(undoMove()!);
    }

    while (reversedHistory.length > 0) {
      Move move = reversedHistory.removeLast();
      moveHistory.add(makePretty(move));
      makeMove(move);
    }
    return moveHistory;
  }

  // debug utility
  perft(int depth) {
    List<Move> moves = generateMoves({'legal': false});
    var nodes = 0;
    var color = turn;

    for (var i = 0, len = moves.length; i < len; i++) {
      makeMove(moves[i]);
      if (!kingAttacked(color)) {
        if (depth - 1 > 0) {
          int child_nodes = perft(depth - 1);
          nodes += child_nodes;
        } else {
          nodes++;
        }
      }
      undoMove();
    }
    return nodes;
  }
}
