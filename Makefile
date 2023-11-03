WASM_OUT_DIR := wasm
WASM_OUT_NAME := libpg-query
WASM_MODULE_NAME := PgQueryModule
LIBPG_QUERY_REPO := https://github.com/gregnr/libpg_query.git
LIBPG_QUERY_BRANCH := fix/ar-command-in-makefile
CACHE_DIR := .cache

OS ?= $(shell uname -s)
ARCH ?= $(shell uname -m)

ifdef EMSCRIPTEN
PLATFORM := emscripten
else ifeq ($(OS),Darwin)
PLATFORM := darwin
else ifeq ($(OS),Linux)
PLATFORM := linux
else
$(error Unsupported platform: $(OS))
endif

ifdef EMSCRIPTEN
ARCH := wasm
endif

PLATFORM_ARCH := $(PLATFORM)-$(ARCH)
SRC_FILES := $(wildcard src/*.cc)
LIBPG_QUERY_DIR := $(CACHE_DIR)/$(PLATFORM_ARCH)/libpg_query
CXXFLAGS := -O3

ifdef EMSCRIPTEN
OUT_FILES := $(foreach EXT,.js .wasm,$(WASM_OUT_DIR)/$(WASM_OUT_NAME)$(EXT))
else
OUT_FILES := build/Release/queryparser.node $(wildcard build/*)
endif

build: $(OUT_FILES)

build-cache: $(LIBPG_QUERY_DIR)

rebuild: clean $(OUT_FILES)

rebuild-cache: clean-cache $(LIBPG_QUERY_DIR)

clean:
	-@ rm -r $(OUT_FILES) > /dev/null 2>&1

clean-cache:
	-@ rm -rf $(LIBPG_QUERY_DIR)

$(LIBPG_QUERY_DIR):
	mkdir -p $(CACHE_DIR)
	git clone -b $(LIBPG_QUERY_BRANCH) --single-branch $(LIBPG_QUERY_REPO) $(LIBPG_QUERY_DIR)
	cd $(LIBPG_QUERY_DIR); $(MAKE) build

$(OUT_FILES): $(LIBPG_QUERY_DIR) $(SRC_FILES)
ifdef EMSCRIPTEN
	@ $(CXX) \
		$(CXXFLAGS) \
		-D NAPI_DISABLE_CPP_EXCEPTIONS \
		-D NODE_ADDON_API_ENABLE_MAYBE \
		-D NAPI_HAS_THREADS \
		-I $(LIBPG_QUERY_DIR) \
		-I ./node_modules/emnapi/include \
		-I ./node_modules/node-addon-api \
		-L ./node_modules/emnapi/lib/wasm32-emscripten \
		-L $(LIBPG_QUERY_DIR) \
		--js-library=./node_modules/emnapi/dist/library_napi.js \
		-s EXPORTED_FUNCTIONS="['_malloc','_free','_napi_register_wasm_v1','_node_api_module_get_api_version_v1']" \
		-s EXPORT_NAME="$(WASM_MODULE_NAME)" \
		-s ENVIRONMENT="web" \
		-s MODULARIZE=1 \
		-s EXPORT_ES6=1 \
		-l pg_query \
		-l emnapi-basic \
		-o $@ \
		$(SRC_FILES)
else
# if not wasm, defer to node-gyp
	yarn rebuild
endif

.PHONY: build build-cache rebuild rebuild-cache clean clean-cache
