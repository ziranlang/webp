include("${CMAKE_CURRENT_LIST_DIR}/WebP.cmake")
ziran_webp_decoder(ziran_webp_android "${ZIRAN_SOURCE_libwebp}")
target_link_libraries("${ZIRAN_ANDROID_TARGET}" PRIVATE ziran_webp_android)
