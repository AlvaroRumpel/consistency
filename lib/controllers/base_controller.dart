abstract class BaseController<T> {
  BaseController() {
    onInit();
  }
  void onInit();

  void onDispose();
}
