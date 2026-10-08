import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> deliverPdf(Uint8List bytes, String name) =>
    deliverFile(bytes, name, 'application/pdf');

Future<void> deliverFile(Uint8List bytes, String name, String mime) async {
  final blob =
      web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.appendChild(anchor);
  try {
    anchor.click();
    await Future<void>.delayed(const Duration(seconds: 1));
  } finally {
    anchor.remove();
    web.URL.revokeObjectURL(url);
  }
}
