// lib/features/blocks/data/blocks_repository.dart
//
// UW 9.3: matches the real routes/blocks.js exactly -- block/unblock
// are both one-directional, reversible, and carry no penalty or
// notification to the blocked user.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/networking/api_endpoints.dart';
import '../domain/blocked_user.dart';

class BlocksRepository {
  BlocksRepository(this._client);
  final ApiClient _client;

  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _client.dio.get(ApiEndpoints.blocks);
    return (response.data['data'] as List)
        .map((j) => BlockedUser.fromJson(j))
        .toList();
  }

  /// Returns the real backend's own message ("User blocked.").
  Future<String> blockUser(String userId) async {
    final response = await _client.dio
        .post(ApiEndpoints.blocks, data: {'userId': userId});
    return response.data['message'] as String;
  }

  /// Returns the real backend's own message ("User unblocked.").
  Future<String> unblockUser(String userId) async {
    final response =
        await _client.dio.delete(ApiEndpoints.blockDetail(userId));
    return response.data['message'] as String;
  }
}

final blocksRepositoryProvider = Provider<BlocksRepository>(
    (ref) => BlocksRepository(ref.watch(apiClientProvider)));

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>(
    (ref) => ref.watch(blocksRepositoryProvider).getBlockedUsers());
