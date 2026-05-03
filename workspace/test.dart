void main() {
  late int x;
  try {
    print(x);
  } catch (e) {
    print(e.runtimeType);
    print("Caught: $e");
  }
}
