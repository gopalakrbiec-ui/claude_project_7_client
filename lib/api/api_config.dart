// Drives openapi_generator via build_runner.
// Run: make gen-api  (or: dart run build_runner build --delete-conflicting-outputs)
// The generated files land in lib/api/generated/ — never edit them by hand.

import 'package:openapi_generator_annotations/openapi_generator_annotations.dart';

@Openapi(
  additionalProperties: AdditionalProperties(
    pubName: 'life_event_editor_api',
    pubAuthor: 'generated',
  ),
  inputSpec: InputSpec.fromFile('openapi.json'),
  generatorName: Generator.dio,
  outputDirectory: 'lib/api/generated',
  runSourceGenOnOutput: true,
)
// ignore: unused_element
class _ApiConfig {}
