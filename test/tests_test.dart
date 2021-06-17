import 'package:chessjs/constants.dart';
import 'package:chessjs/pieces.dart';
import 'package:test/test.dart';
import 'package:chessjs/chessjs.dart' as chessjs;

import 'constants.dart';

void main() {
  group("Perft", () {
    perfts.forEach((perft) {
      chessjs.Chess chess = chessjs.Chess();
      chess.load(perft['fen']);

      test(perft['fen'], () {
        var nodes = chess.perft(perft['depth']);
        expect(nodes, equals(perft['nodes']));
      });
    });
  });

  group("Single Square Move Generation", () {
    positions.forEach((position) {
      chessjs.Chess chess = chessjs.Chess();
      chess.load(position['fen']);

      test(position['fen'] + ' ' + position['square'], () {
        var moves = chess.moves(
            {'square': position['square'], 'verbose': position['verbose']});
        var passed = position['moves'].length == moves.length;

        for (int j = 0; j < moves.length; j++) {
          if (!position['verbose']) {
            passed = passed && moves[j] == position['moves'][j];
          } else {
            for (var k in moves[j].keys) {
              passed = passed && moves[j][k] == position['moves'][j][k];
            }
          }
        }
        expect(passed, isTrue);
      });
    });
  });

  group("Checkmate", () {
    chessjs.Chess chess = chessjs.Chess();

    checkmates.forEach((checkmate) {
      chess.load(checkmate);

      test(checkmate, () {
        expect(chess.inCheckmate, isTrue);
      });
    });
  });

  group("Stalemate", () {
    stalemates.forEach((stalemate) {
      chessjs.Chess chess = chessjs.Chess();
      chess.load(stalemate);

      test(stalemate, () {
        expect(chess.inStalemate, isTrue);
      });
    });
  });

  group("Insufficient Material", () {
    positionsInsufficientMaterial.forEach((position) {
      chessjs.Chess chess = chessjs.Chess();
      chess.load(position['fen']);

      test(position['fen'], () {
        if (position['draw']) {
          expect(chess.insufficientMaterial && chess.inDraw, isTrue);
        } else {
          expect(!chess.insufficientMaterial && !chess.inDraw, isTrue);
        }
      });
    });
  });

  group("Threefold Repetition", () {
    positionsThreefoldRepetition.forEach((position) {
      chessjs.Chess chess = chessjs.Chess();
      chess.load(position['fen']);

      test(position['fen'], () {
        bool passed = true;
        for (int j = 0; j < position['moves'].length; j++) {
          if (chess.inThreefoldRepetition) {
            passed = false;
            break;
          }
          chess.move(position['moves'][j]);
        }

        expect(passed && chess.inThreefoldRepetition && chess.inDraw, isTrue);
      });
    });
  });

  group("Algebraic Notation", () {
    positionsAlgebraicNotation.forEach((position) {
      chessjs.Chess chess = chessjs.Chess();
      bool passed = true;
      chess.load(position['fen']);

      test(position['fen'], () {
        var moves = chess.moves();
        if (moves.length != position['moves'].length) {
          passed = false;
        } else {
          for (int j = 0; j < moves.length; j++) {
            if (!position['moves'].contains(moves[j])) {
              passed = false;
              break;
            }
          }
        }
        expect(passed, isTrue);
      });
    });
  });

  group("Get/Put/Remove", () {
    chessjs.Chess chess = chessjs.Chess();
    bool passed = true;

    positionsGetPutRemove.forEach((position) {
      passed = true;
      chess.clear();

      test("position should pass - " + position['should_pass'].toString(), () {
        /* places the pieces */
        for (var square in position['pieces'].keys) {
          passed = passed && chess.put(position['pieces'][square], square);
        }

        /* iterate over every square to make sure get returns the proper
         * piece values/color
         */
        for (var square in SQUARES.keys) {
          if (!(position['pieces'].containsKey(square))) {
            if (chess.get(square) != null) {
              passed = false;
              break;
            }
          } else {
            var piece = chess.get(square);
            if (!(piece != null &&
                piece.type == position['pieces'][square].type &&
                piece.color == position['pieces'][square].color)) {
              passed = false;
              break;
            }
          }
        }

        if (passed) {
          /* remove the pieces */
          for (var square in SQUARES.keys) {
            Piece? piece = chess.remove(square);
            if ((!(position['pieces'].containsKey(square))) && piece != null) {
              passed = false;
              break;
            }

            if (piece != null &&
                (position['pieces'][square].type != piece.type ||
                    position['pieces'][square].color != piece.color)) {
              passed = false;
              break;
            }
          }
        }

        /* finally, check for an empty board */
        passed = passed && (chess.fen == '8/8/8/8/8/8/8/8 w - - 0 1');

        /* some tests should fail, so make sure we're supposed to pass/fail each
         * test
         */
        passed = (passed == position['should_pass']);

        expect(passed, isTrue);
      });
    });
  });

  group("FEN", () {
    positionsFEN.forEach((position) {
      chessjs.Chess chess = chessjs.Chess();

      test(
          position['fen'].toString() +
              ' (' +
              position['should_pass'].toString() +
              ')', () {
        chess.load(position['fen'] as String);
        expect(
            (chess.fen == position['fen']) == position['should_pass'], isTrue);
      });
    });
  });

  group("PGN", () {
    positionsPGN.forEach((position) {
      test(position["fen"], () {
        chessjs.Chess chess = (position.containsKey("starting_position"))
            ? chessjs.Chess.fromFEN(position['starting_position'])
            : chessjs.Chess();
        bool passed = true;
        String errorMessage = "";
        for (int j = 0; j < position['moves'].length; j++) {
          if (chess.move(position['moves'][j]) == null) {
            errorMessage =
                "move() did not accept " + position['moves'][j] + " : ";
            break;
          }
        }

        for (int k = 0; k < position['header'].length; k += 2) {
          chess.header[position['header'][k]] = position['header'][k + 1];
        }
        //chess.header.apply(null, position['header']);
        var pgn = chess.pgn({
          'max_width': position['max_width'],
          'newline_char': position['newline_char']
        });
        var fen = chess.fen;
        passed = pgn == position['pgn'] && fen == position['fen'];
        expect(passed && errorMessage.length == 0, isTrue);
      });
    });
  });

  group("Load PGN", () {
    chessjs.Chess chess = chessjs.Chess();

    var newlineChars = ['\n', '<br />', '\r\n', 'BLAH'];

    testsLoadPGN.forEach((t) {
      newlineChars.forEach((newline) {
        test(t['fen'], () {
          var result =
              chess.loadPgn(t['pgn'].join(newline), {'newline_char': newline});
          bool should_pass = t['expect'];

          /* some tests are expected to fail */
          if (should_pass) {
            /* some PGN's tests contain comments which are stripped during parsing,
           * so we'll need compare the results of the load against a FEN string
           * (instead of the reconstructed PGN [e.g. test.pgn.join(newline)])
           */

            if (t.containsKey("fen")) {
              expect(result, isTrue);
              expect(chess.fen, equals(t["fen"]));
              //print(chess.fen());
              //print(t["fen"]);
            } else {
              expect(result, isTrue);
              expect(chess.pgn({'max_width': 65, 'newline_char': newline}),
                  equals(t['pgn'].join(newline)));
              //print(chess.pgn({ 'max_width': 65, 'newline_char': newline }));
              //print(t['pgn'].join(newline));
            }
          } else {
            /* this test should fail, so make sure it does */
            expect(result, equals(should_pass));
          }
        });
      });
    });

    // special case dirty file containing a mix of \n and \r\n
    test('dirty pgn', () {
      var result = chess.loadPgn(pgn, {'newline_char': '\r?\n'});
      expect(result, isNotNull);

      expect(chess.loadPgn(pgn), isNotNull);
      expect(!chess.pgn().contains(new RegExp(r"^\[\[")), isTrue);
    });
  });

  group("Make Move", () {
    positionsMakeMove.forEach((position) {
      chessjs.Chess chess = chessjs.Chess();
      chess.load(position['fen']);
      test(
          position['fen'] +
              ' (' +
              position['move'] +
              ' ' +
              position['legal'].toString() +
              ')', () {
        var result = chess.move(position['move']);
        if (position['legal']) {
          expect(result, isTrue);
          expect(chess.fen, equals(position['next']));
          if (position.containsKey("captured")) {
            expect(chess.history.removeLast().move.captured,
                equals(position["captured"]));
          }
        } else {
          expect(result, isFalse);
        }
      });
    });
  });

  group("Validate FEN", () {
    positionsValidateFEN.forEach((position) {
      test(
          position['fen'] +
              ' (valid: ' +
              (position['error_number'] == 0).toString() +
              ')', () {
        var result = chessjs.Chess.validateFen(position['fen']);
        expect(result['error_number'], equals(position['error_number']));
      });
    });
  });

  /// OLD TEST
  group("History", () {
    chessjs.Chess chess = chessjs.Chess();

    testsHISTORY.forEach((t) {
      bool passed = true;

      test(t['fen'], () {
        chess.reset();

        for (int j = 0; j < t['moves'].length; j++) {
          chess.move(t['moves'][j]);
        }

        var history;
        if (t['verbose']) {
          history = chess.getHistoryVerbose();
        } else
          history = chess.getHistorySAN();

//        var history = chess.getHistorySAN({'verbose': t['verbose']});
        if (t['fen'] != chess.fen) {
          passed = false;
        } else if (history.length != t['moves'].length) {
          passed = false;
        } else {
          for (int j = 0; j < t['moves'].length; j++) {
            if (!t['verbose']) {
              if (history[j] != t['moves'][j]) {
                passed = false;
                break;
              }
            } else {
              for (var key in history[j].keys) {
                if (history[j][key] != t['moves'][j][key]) {
                  passed = false;
                  break;
                }
              }
            }
          }
        }
        expect(passed, isTrue);
      });
    });
  });

  group('Regression Tests', () {
    // Github Issue #32 reported by AlgoTrader
    test('Issue #32 - castling flag reappearing', () {
      chessjs.Chess chess = chessjs.Chess.fromFEN(
          'b3k2r/5p2/4p3/1p5p/6p1/2PR2P1/BP3qNP/6QK b k - 2 28');
      chess.move({'from': 'a8', 'to': 'g2'});
      expect(chess.fen,
          equals('4k2r/5p2/4p3/1p5p/6p1/2PR2P1/BP3qbP/6QK w k - 0 29'));
    });
  });
}
