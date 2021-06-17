import 'constants.dart';
import 'color.dart';

int rank(int i) {
  return i >> 4;
}

int file(int i) {
  return i & 15;
}

String algebraic(int i) {
  var f = file(i), r = rank(i);
  return 'abcdefgh'.substring(f, f + 1) + '87654321'.substring(r, r + 1);
}

Color swapColor(Color c) {
  return c == WHITE ? BLACK : WHITE;
}

bool isDigit(String c) {
  return '0123456789'.contains(c);
}

String trim(String str) {
  return str.replaceAll(new RegExp(r"^\s+|\s+$"), '');
}
