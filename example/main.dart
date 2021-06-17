import 'dart:math';
import 'dart:ui';

import 'package:chessjs/chessjs.dart' as chessjs;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChessJsDemo(),
    );
  }
}

class ChessJsDemo extends StatefulWidget {
  @override
  _ChessJsDemoState createState() => _ChessJsDemoState();
}

class _ChessJsDemoState extends State<ChessJsDemo> {
  chessjs.Chess chess = chessjs.Chess();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 500,
                child: Text(chess.ascii,
                    style: TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.justify),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                  onPressed: () {
                    final moves = chess.moves();
                    Random random = Random();
                    int nextMoveIndex = random.nextInt(moves.length);
                    setState(() {
                      chess.move(moves[nextMoveIndex]);
                    });
                    if (chess.gameOver) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(title: Text('Game Over'));
                          });
                    }
                  },
                  child: Text('Make Random Move')),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                  onPressed: () {
                    if (chess.history.isEmpty) {
                      showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                                title: Text('No Previous Moves'));
                          });
                    } else
                      setState(() {
                        chess.undoMove();
                      });
                  },
                  child: Text('Take Back')),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('${chess.getHistorySAN()}'),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('${chess.getHistoryVerbose()}'),
            ),
          ],
        ),
      ),
    );
  }
}
