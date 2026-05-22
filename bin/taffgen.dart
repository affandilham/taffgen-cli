import 'package:taff_gen/src/core/runner.dart';

void main(List<String> args) async {
  final runner = TaffGenRunner();
  await runner.execute(args);
}
