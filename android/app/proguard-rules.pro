# MediaPipe / LiteRT / Flutter Gemma
-keep class com.google.mediapipe.** { *; }
-keep class com.google.protobuf.** { *; }
-keep class com.google.flatbuffers.** { *; }

-dontwarn com.google.mediapipe.**
-dontwarn com.google.protobuf.**
-dontwarn com.google.flatbuffers.**

# Specific missing classes from R8
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

-keep class com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile { *; }
-keep class com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate { *; }