# flutter_gemma / MediaPipe LLM on-device inference.
# R8 strips/warns on MediaPipe + protobuf + AutoValue classes that are
# referenced reflectively or via generated code. Keep them and silence the
# unresolved-reference warnings R8 reported for the release build.
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

-dontwarn com.google.auto.value.**

# Exact missing classes flagged by R8 (build/app/outputs/mapping/release/missing_rules.txt)
-dontwarn com.google.auto.value.extension.memoized.Memoized
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate
