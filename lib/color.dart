import 'constants.dart';

class ColorMap<T> {
  T _white;
  T _black;
  ColorMap(T value)
      : _white = value,
        _black = value;
  ColorMap.clone(ColorMap other)
      : _white = other._white,
        _black = other._black;

  T operator [](Color color) {
    return (color == Color.WHITE) ? _white : _black;
  }

  void operator []=(Color color, T value) {
    if (color == Color.WHITE) {
      _white = value;
    } else {
      _black = value;
    }
  }
}
