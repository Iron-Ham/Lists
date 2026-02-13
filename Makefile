# ABOUTME: Makefile for ListKit development.
# ABOUTME: Run `make help` to see available commands.

.PHONY: help setup install generate open build test test-listkit test-lists benchmark clean lint format install-hooks

# Colors
RESET  := \033[0m
BOLD   := \033[1m
DIM    := \033[2m
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m

DESTINATION := platform=iOS Simulator,name=iPhone 17 Pro
DERIVED_DATA := DerivedData

# Default target
help:
	@echo ""
	@echo "$(BOLD)$(CYAN)  ┌──────────────────────────────────────────────────────────────┐$(RESET)"
	@echo "$(BOLD)$(CYAN)  │$(RESET)                       $(BOLD)ListKit$(RESET)                                $(BOLD)$(CYAN)│$(RESET)"
	@echo "$(BOLD)$(CYAN)  └──────────────────────────────────────────────────────────────┘$(RESET)"
	@echo ""
	@echo "  $(BOLD)$(GREEN)◆ Setup$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "setup" "Complete first-time setup (install + generate)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "install" "Install Tuist and fetch dependencies"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "generate" "Generate Xcode project from Tuist manifests"
	@echo ""
	@echo "  $(BOLD)$(BLUE)◆ Development$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "open" "Generate and open project in Xcode"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "build" "Build ListKit and Lists frameworks"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "clean" "Clean build artifacts and Tuist cache"
	@echo ""
	@echo "  $(BOLD)$(YELLOW)◆ Testing$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "test" "Run all test targets"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "test-listkit" "Run ListKit tests only"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "test-lists" "Run Lists tests only"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "benchmark" "Run benchmarks (ListKit vs Apple/IGListKit/RC)"
	@echo ""
	@echo "  $(BOLD)◆ Code Quality$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "lint" "Lint Sources/, Tests/, and Example/ with SwiftFormat"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "format" "Format code with SwiftFormat"
	@printf "    $(CYAN)%-24s$(RESET) %s\n" "install-hooks" "Install git pre-commit hook"
	@echo ""
	@echo "  $(BOLD)◆ Examples$(RESET)"
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@echo "    $(DIM)# First-time setup$(RESET)"
	@echo "    make setup"
	@echo ""
	@echo "    $(DIM)# Build both frameworks$(RESET)"
	@echo "    make build"
	@echo ""
	@echo "    $(DIM)# Run only Lists tests$(RESET)"
	@echo "    make test-lists"
	@echo ""
	@echo "  $(DIM)──────────────────────────────────────────────────────────────$(RESET)"
	@echo "  $(BOLD)First time?$(RESET) Run $(GREEN)make setup$(RESET)"
	@echo ""

# =============================================================================
# Setup
# =============================================================================

setup: install generate install-hooks
	@echo ""
	@echo "$(GREEN)Setup complete!$(RESET) Run '$(CYAN)make open$(RESET)' to open in Xcode."

install:
	@if ! command -v tuist &> /dev/null; then \
		echo "Installing Tuist via Homebrew..."; \
		brew tap tuist/tuist; \
		brew install --formula tuist; \
	else \
		echo "Tuist already installed: $$(tuist version)"; \
	fi

generate:
	@echo "Generating Xcode project..."
	tuist generate --no-open

# =============================================================================
# Development
# =============================================================================

open:
	@if [ ! -f "ListKit.xcworkspace/contents.xcworkspacedata" ]; then \
		echo "Project not generated. Running 'make generate' first..."; \
		$(MAKE) generate; \
	fi
	open ListKit.xcworkspace

build:
	xcodebuild build \
		-workspace ListKit.xcworkspace \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		| xcpretty || xcodebuild build \
		-workspace ListKit.xcworkspace \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)
	xcodebuild build \
		-workspace ListKit.xcworkspace \
		-scheme Lists \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		| xcpretty || xcodebuild build \
		-workspace ListKit.xcworkspace \
		-scheme Lists \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)

# =============================================================================
# Testing
# =============================================================================

test: test-listkit test-lists

test-listkit:
	xcodebuild test \
		-workspace ListKit.xcworkspace \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing ListKitTests \
		| xcpretty || xcodebuild test \
		-workspace ListKit.xcworkspace \
		-scheme ListKit \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing ListKitTests

test-lists:
	xcodebuild test \
		-workspace ListKit.xcworkspace \
		-scheme Lists \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing ListsTests \
		| xcpretty || xcodebuild test \
		-workspace ListKit.xcworkspace \
		-scheme Lists \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-only-testing ListsTests

benchmark:
	xcodebuild test \
		-workspace ListKit.xcworkspace \
		-scheme Benchmarks \
		-configuration Release \
		ENABLE_TESTABILITY=YES \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		| xcpretty || xcodebuild test \
		-workspace ListKit.xcworkspace \
		-scheme Benchmarks \
		-configuration Release \
		ENABLE_TESTABILITY=YES \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA)

# =============================================================================
# Code Quality
# =============================================================================

lint:
	swiftformat --lint Sources/ Tests/ Example/

format:
	swiftformat Sources/ Tests/ Example/

# =============================================================================
# Maintenance
# =============================================================================

clean:
	@echo "Cleaning derived data..."
	rm -rf $(DERIVED_DATA)
	@rm -rf ~/Library/Developer/Xcode/DerivedData/ListKit-* 2>/dev/null || true
	@echo "Cleaning Tuist cache..."
	tuist clean 2>/dev/null || true
	@echo "$(GREEN)Clean complete.$(RESET)"

install-hooks:
	@if [ -d ".git" ]; then \
		cp scripts/pre-commit .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "Git hooks installed."; \
	else \
		echo "$(DIM)Not a git repo — skipping hook install.$(RESET)"; \
	fi
