cmake_minimum_required(VERSION 3.22)
project(ZiranWebpOracle C)
include("${CMAKE_CURRENT_LIST_DIR}/WebP.cmake")
ziran_webp_decoder(imagewebp "${WEBP_DIR}")
