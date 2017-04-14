PKG=pied
BUILD_DIR=build
PONYC=ponyc
PONY_SRC=$(shell find . -name "*.pony")
BIN_DIR=$(BUILD_DIR)/release
BIN=$(BIN_DIR)/$(PKG)
DEBUG_DIR=$(BUILD_DIR)/debug
DEBUG=$(DEBUG_DIR)/$(PKG)
TEST_SRC=$(PKG)/test
TEST_BIN=$(BUILD_DIR)/test
BENCH_SRC=$(PKG)/bench
BENCH_BIN=$(BUILD_DIR)/bench
prefix=/usr/local

all: $(BIN_DIR) test $(BIN) ## Run tests and build the package

run: $(BIN) ## Build and run the package
	$(BIN)

debug: $(DEBUG) ## Build a and run the package with --debug
	$(DEBUG)

test: $(TEST_BIN) runtest ## Build and run tests

$(TEST_BIN): $(BUILD_DIR) $(PONY_SRC)
	$(PONYC) -o $(BUILD_DIR) --path . $(TEST_SRC)

runtest: ## Run the tests
	$(TEST_BIN)

bench: $(BENCH_BIN) runbench ## Build and run benchmarks

$(BENCH_BIN): $(BUILD_DIR) $(PONY_SRC)
	$(PONYC) -o $(BUILD_DIR) --path . $(BENCH_SRC)

runbench: ## Run benchmarks
	$(BENCH_BIN)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(BIN): $(PONY_SRC) 
	$(PONYC) -o $(BIN_DIR) -p . $(PKG)

$(DEBUG_DIR):
	mkdir -p $(DEBUG_DIR)

$(DEBUG): $(PONY_SRC) 
	$(PONYC) --debug -o $(DEBUG_DIR) $(PKG)

doc: $(PONY_SRC) ## Build the documentation 
	$(PONYC) -o $(BUILD_DIR) --docs --path . --pass=docs $(PKG)

clean: ## Remove all artifacts
	-rm -rf $(BUILD_DIR)

 
install: ## Install binary in $(prefix). Default prefix=/usr/local
	mkdir -p $(prefix)/bin
	cp $(BIN) $(prefix)/bin

uninstall: ## Remove binary from prefix.
	rm $(prefix)/bin/$(PKG)


.PHONY: help

help: ## Show help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\\n", $$1, $$2}'
	@echo
	@echo "Install instructions:"
	@echo "  make"
	@echo "  sudo make install"
	@echo "or, for your user only (assuming $$HOME/bin is in your PATH)"
	@echo "  make"
	@echo "  make install prefix=$$HOME"
