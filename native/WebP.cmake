# Decoder-only libwebp recipe shared by package artifacts and native consumers.
# include("<webp-package>/native/WebP.cmake")
# ziran_webp_decoder(<target-name> "<pinned-libwebp-source>")
include_guard(GLOBAL)

function(ziran_webp_decoder target webp_dir)
    if(TARGET "${target}")
        message(FATAL_ERROR "WebP decoder target already exists: ${target}")
    endif()
    if(NOT EXISTS "${webp_dir}/CMakeLists.txt" OR
       NOT EXISTS "${webp_dir}/src/demux/anim_decode.c")
        message(FATAL_ERROR "No libwebp source at ${webp_dir}")
    endif()
    foreach(option ANIM_UTILS CWEBP DWEBP GIF2WEBP IMG2WEBP VWEBP WEBPINFO
            LIBWEBPMUX WEBPMUX EXTRAS FUZZTEST)
        set(WEBP_BUILD_${option} OFF CACHE BOOL "" FORCE)
    endforeach()
    set(WEBP_LINK_STATIC ON CACHE BOOL "" FORCE)
    set(WEBP_USE_THREAD OFF CACHE BOOL "" FORCE)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
    add_subdirectory("${webp_dir}" "${CMAKE_CURRENT_BINARY_DIR}/libwebp" EXCLUDE_FROM_ALL)
    set(sources
        $<TARGET_OBJECTS:webpdecode> $<TARGET_OBJECTS:webpdspdecode>
        $<TARGET_OBJECTS:webputilsdecode>
        "${webp_dir}/src/demux/demux.c" "${webp_dir}/src/demux/anim_decode.c")
    # The Android CPU probe is included once in this aggregate archive.
    if(TARGET cpufeatures-webp)
        list(APPEND sources "${ANDROID_NDK}/sources/android/cpufeatures/cpu-features.c")
    endif()
    add_library("${target}" STATIC ${sources})
    target_include_directories("${target}" PRIVATE "${webp_dir}")
    if(TARGET cpufeatures-webp)
        target_include_directories("${target}" PRIVATE "${ANDROID_NDK}/sources/android/cpufeatures")
        target_link_libraries("${target}" PRIVATE dl)
    endif()
    foreach(codec_target "${target}" webpdecode webpdspdecode webputilsdecode)
        target_compile_options("${codec_target}" PRIVATE -ffunction-sections -fdata-sections)
        set_target_properties("${codec_target}" PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endforeach()
endfunction()
