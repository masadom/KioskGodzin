import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiosk_godzin/data/shift_remote_repository.dart';
import 'package:kiosk_godzin/models/shift.dart';

void main() {
  const baseUrl = 'http://example.com';

  group('RemoteShiftRepository', () {
    group('findActiveShiftForEmployee', () {
      test('calls the correct URL and parses the response', () async {
        final client = MockClient((req) async {
          expect(
            req.url.toString(),
            '$baseUrl/shifts?employee_id=1&_sort=id&_order=desc',
          );
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'employee_id': 1,
                'started_at': '2024-01-01T10:00:00Z',
                'ended_at': null,
              }
            ]),
            200,
          );
        });

        final realClient = http.Client;
        http.Client = () => client as http.Client;

        final repo = RemoteShiftRepository(baseUrl: baseUrl);
        final shift = await repo.findActiveShiftForEmployee(1);

        expect(shift, isA<Shift>());
        expect(shift?.employeeId, 1);
        expect(shift?.endedAt, isNull);

        http.Client = realClient;
      });
    });

    group('endShiftByEmployee', () {
      test('calls the correct URL and patches the shift', () async {
        final client = MockClient((req) async {
          if (req.method == 'GET') {
            expect(
              req.url.toString(),
              '$baseUrl/shifts?employee_id=1&_sort=id&_order=desc',
            );
            return http.Response(
              jsonEncode([
                {
                  'id': 'abc-123',
                  'employee_id': 1,
                  'started_at': '2024-01-01T10:00:00Z',
                  'ended_at': null,
                }
              ]),
              200,
            );
          }
          if (req.method == 'PATCH') {
            expect(req.url.toString(), '$baseUrl/shifts/abc-123');
            final body = jsonDecode(req.body) as Map;
            expect(body.containsKey('ended_at'), isTrue);
            return http.Response('', 200);
          }
          return http.Response('Not Found', 404);
        });

        final realClient = http.Client;
        http.Client = () => client as http.Client;

        final repo = RemoteShiftRepository(baseUrl: baseUrl);
        await repo.endShiftByEmployee(1);

        http.Client = realClient;
      });
    });
  });
}