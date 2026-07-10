// Small named-JSON-blob store. Backed by a file under the app support
// directory natively, and by localStorage on web (path_provider has no web
// implementation).
export 'local_json_store_io.dart'
    if (dart.library.js_interop) 'local_json_store_web.dart';
