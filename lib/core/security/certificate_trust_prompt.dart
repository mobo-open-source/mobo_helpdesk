import 'package:flutter/material.dart';

import '../navigation/navigation_keys.dart';
import 'trusted_certificates.dart';

/// Makes sure the server behind [fullUrl] presents a certificate the app can
/// trust, asking the user to approve it when it is self-signed or issued by a
/// private authority.
///
/// Returns true when the connection may proceed, false when the user declined.
Future<bool> ensureServerTrusted(String fullUrl) async {
  final uri = Uri.tryParse(fullUrl);
  if (uri == null || uri.host.isEmpty || uri.scheme != 'https') return true;

  final port = uri.hasPort ? uri.port : 443;
  final untrusted = await probeCertificate(uri.host, port);
  if (untrusted == null) return true;

  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return false;

  final approved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CertificateDialog(untrusted),
  );

  if (approved == true) {
    await TrustedCertificates.trust(
      untrusted.host,
      untrusted.port,
      untrusted.certificate,
    );
    return true;
  }
  return false;
}

class _CertificateDialog extends StatelessWidget {
  const _CertificateDialog(this.info);

  final UntrustedCertificate info;

  @override
  Widget build(BuildContext context) {
    final cert = info.certificate;
    return AlertDialog(
      title: Text(
        info.changed ? 'Server certificate changed' : 'Untrusted certificate',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.changed
                  ? 'The certificate of ${info.host} is different from the one '
                        'you approved before. This can mean the server was '
                        'reconfigured, or that someone is intercepting the '
                        'connection. Continue only if your administrator '
                        'confirmed the change.'
                  : '${info.host} uses a certificate that this device does '
                        'not trust (for example a self-signed one). Trust it '
                        'only if your administrator gave you the fingerprint '
                        'below and it matches.',
            ),
            const SizedBox(height: 12),
            _row('Subject', cert.subject),
            _row('Issuer', cert.issuer),
            _row('Valid until', cert.endValidity.toLocal().toString()),
            _row('SHA-256', info.fingerprint),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Trust this server'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      style: const TextStyle(fontSize: 12),
    ),
  );
}
