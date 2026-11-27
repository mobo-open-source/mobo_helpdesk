import 'dart:io';
import 'package:http/io_client.dart';

/// Global [IOClient] used for direct HTTP requests alongside the `odoo_rpc`
/// package. It uses the platform's default TLS validation, so only
/// certificates trusted by the system are accepted.
final ioClient = IOClient(HttpClient());
