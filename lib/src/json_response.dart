import 'dart:convert';

import 'package:shelf/shelf.dart';

extension JsonResponse on Response {
  static Response ok(Object? body) => Response.ok(
    jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response badRequest(Object? body) => Response.badRequest(
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response internalServerError(Object? body) =>
      Response.internalServerError(
        body: jsonEncode(body),
        headers: {'Content-Type': 'application/json'},
      );

  static Response unauthorized(Object? body) => Response.unauthorized(
    jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response notFound(Object? body) => Response.notFound(
    jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response forbidden(Object? body) => Response.forbidden(
    jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response conflict(Object? body) => Response(
    409,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response tooManyRequests(Object? body) => Response(
    429,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );

  static Response serviceUnavailable(Object? body) => Response(
    503,
    body: jsonEncode(body),
    headers: {'Content-Type': 'application/json'},
  );
}
