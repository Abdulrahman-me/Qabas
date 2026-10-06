import 'package:qabas/core/error/result.dart';
import 'package:qabas/features/dev_tools/domain/repositories/dev_tools_repository.dart';

final class DevToolsActions {
  const DevToolsActions(this._repository);
  final DevToolsRepository _repository;
  Future<Result<DevSnapshot>> inspect() => _repository.inspect();
  Future<Result<DevSnapshot>> change(DevOption option, Object? value) => _repository.change(option, value);
  Future<Result<DevSnapshot>> probe() => _repository.probe();
}
