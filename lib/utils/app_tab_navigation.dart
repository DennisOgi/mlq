/// Lightweight tab navigation for the main shell without circular imports.
class AppTabNavigation {
  static void Function(int index)? _handler;

  static void register(void Function(int index) handler) {
    _handler = handler;
  }

  static void unregister() {
    _handler = null;
  }

  static void goToTab(int index) {
    _handler?.call(index);
  }
}
