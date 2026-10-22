# JNI glue: Kotlin calls these, they call the engine's C interface (ttk_*) in libTatakikunEngine.so,
# which scripts/build-android.sh builds with the Swift SDK for Android into src/main/jniLibs.
cmake_minimum_required(VERSION 3.22)
project(tatakikun_jni C)
add_library(TatakikunEngine SHARED IMPORTED)
# The Swift-built library has no SONAME: link it by name, not by this Mac's path.
set_target_properties(TatakikunEngine PROPERTIES IMPORTED_LOCATION
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libTatakikunEngine.so IMPORTED_NO_SONAME TRUE)
add_library(tatakikun_jni SHARED jni.c)
target_link_libraries(tatakikun_jni TatakikunEngine)
