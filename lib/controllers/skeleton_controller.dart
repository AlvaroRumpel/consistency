import 'base_controller.dart';

class SkeletonController extends BaseController<int> {
  SkeletonController(super.initialState);

  void changePage(int index) {
    emit(index);
  }
}
