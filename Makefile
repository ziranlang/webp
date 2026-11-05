ZIRAN_ROOT ?= $(if $(ZIRAN_TOOLCHAIN_ROOT),$(ZIRAN_TOOLCHAIN_ROOT),../../ziran)
ZIRAN ?= $(ZIRAN_ROOT)/build/bin/ziran
CC ?= cc
IMAGE_CODEC_ROOT ?= ../image-codec

build/bin/package_tool: tools/package_tool.zi Makefile
	mkdir -p build/bin build/scratch/package-tool
	build-queue -- "$(ZIRAN)" build --target=c --entry package_tool:main --root tools --module-path "std=$(ZIRAN_ROOT)/std" -o build/scratch/package-tool tools/package_tool.zi
	build-queue -- $(CC) -std=c99 -O2 -I"$(ZIRAN_ROOT)/include" -Ibuild/scratch/package-tool build/scratch/package-tool/*.c -lm -o build/bin/package_tool

build/bin/webp-oracle: tools/oracle.zi src/facade.zi src/libwebp.zi src/native_api.zi src/riff.zi src/engine.zi build/native/libimagewebp.a Makefile
	mkdir -p build/bin build/scratch/oracle
	build-queue -- "$(ZIRAN)" build --target=c --entry oracle:main --root tools --module-path webp=src --module-path "image_codec=$(IMAGE_CODEC_ROOT)/src" --module-path "std=$(ZIRAN_ROOT)/std" -o build/scratch/oracle tools/oracle.zi
	build-queue -- $(CC) -std=c99 -O2 -I"$(ZIRAN_ROOT)/include" -Ibuild/scratch/oracle build/scratch/oracle/*.c build/native/libimagewebp.a -lm -o build/bin/webp-oracle

build/bin/webp-bench: tools/bench.zi $(wildcard src/*.zi) build/native/libimagewebp.a Makefile
	mkdir -p build/bin build/scratch/bench
	build-queue -- "$(ZIRAN)" build --target=c --entry bench:main --root tools --module-path webp_private=src --module-path "image_codec=$(IMAGE_CODEC_ROOT)/src" --module-path "std=$(ZIRAN_ROOT)/std" -o build/scratch/bench tools/bench.zi
	build-queue -- $(CC) -std=c99 -O2 -I"$(ZIRAN_ROOT)/include" -Ibuild/scratch/bench build/scratch/bench/*.c build/native/libimagewebp.a -lm -o build/bin/webp-bench

.PHONY: native
native:
	build-queue -- sh native/build.sh "$(WEBP_SOURCE)"
