// test/core/friendly_error_message_test.dart

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nagaguno_mobile/core/utils/friendly_error_message.dart';

RequestOptions _fakeOptions() => RequestOptions(path: '/test');

void main() {
  group('friendlyErrorMessage', () {
    test(
        'a connection timeout gets UW 19\'s exact offline wording, not the generic one',
        () {
      final error = DioException(
          requestOptions: _fakeOptions(),
          type: DioExceptionType.connectionTimeout);
      expect(friendlyErrorMessage(error),
          'You appear to be offline. Check your connection and try again.');
    });

    test('a receive timeout gets the same offline wording', () {
      final error = DioException(
          requestOptions: _fakeOptions(),
          type: DioExceptionType.receiveTimeout);
      expect(friendlyErrorMessage(error),
          'You appear to be offline. Check your connection and try again.');
    });

    test(
        'a connection error (e.g. no network at all) gets UW 19\'s exact '
        'offline wording, same as a timeout -- REAL BUG FOUND AND FIXED: '
        'this used to assert a different, non-spec string split by Dio\'s '
        'exception subtype, which is exactly the bug friendly_error_message.dart '
        'was just corrected to stop doing', () {
      final error = DioException(
          requestOptions: _fakeOptions(),
          type: DioExceptionType.connectionError);
      expect(friendlyErrorMessage(error),
          'You appear to be offline. Check your connection and try again.');
    });

    test(
        'prefers the real backend\'s own message when the response included one',
        () {
      final error = DioException(
        requestOptions: _fakeOptions(),
        type: DioExceptionType.badResponse,
        response: Response(
            requestOptions: _fakeOptions(),
            data: {'message': 'That email is already registered.'}),
      );
      expect(friendlyErrorMessage(error), 'That email is already registered.');
    });

    test(
        'falls back to a generic message when the backend response has no message field',
        () {
      final error = DioException(
        requestOptions: _fakeOptions(),
        type: DioExceptionType.badResponse,
        response:
            Response(requestOptions: _fakeOptions(), data: {'success': false}),
      );
      expect(friendlyErrorMessage(error),
          'Something went wrong. Please try again.');
    });

    test('a non-DioException error also gets the generic fallback, not a crash',
        () {
      expect(friendlyErrorMessage(Exception('some other error')),
          'Something went wrong. Please try again.');
    });
  });
}
