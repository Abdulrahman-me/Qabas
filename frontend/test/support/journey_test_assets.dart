import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:qabas/mock_backend/fixtures.dart';

/// Flutter's Chrome test harness does not service rootBundle asset requests.
/// The existing test asset server exposes development catalog and grading fixtures on localhost.
Fixtures journeyTestAssets() => !kIsWeb
    ? Fixtures()
    : Fixtures(
        read: (path) async {
          final client = Dio();
          try {
            return (await client.get<String>(
              'http://localhost:8284/mock_fixture/${path.substring('assets/mocks/'.length)}',
              options: Options(responseType: ResponseType.plain),
            )).data!;
          } finally {
            client.close();
          }
        },
      );
