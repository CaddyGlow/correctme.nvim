.PHONY: help test lint fmt check docs clean all install pre-commit

# Default target
all: fmt lint test

# Help target
help:
	@echo "Available targets:"
	@echo "  all      - Run fmt, lint, and test"
	@echo "  test     - Run tests with busted"
	@echo "  lint     - Check code formatting with stylua"
	@echo "  fmt      - Format code with stylua"
	@echo "  check    - Run lint and test (CI equivalent)"
	@echo "  docs     - Generate vim documentation (requires pandoc)"
	@echo "  clean    - Clean generated files"
	@echo "  install  - Install dependencies"
	@echo "  pre-commit - Run pre-commit hooks on all files"

# Test with busted
test:
	@echo "Running tests..."
	busted --config-file=.busted

# Check code formatting
lint:
	@echo "Checking code formatting..."
	stylua --check .

# Format code
fmt:
	@echo "Formatting code..."
	stylua .

# Run checks (equivalent to CI)
check: lint test
	@echo "All checks passed!"

# Generate documentation
docs:
	@echo "Generating vim documentation..."
	@if command -v panvimdoc >/dev/null 2>&1; then \
		panvimdoc --project-name correctme --input-file README.md; \
	else \
		echo "Error: panvimdoc not installed. Make sure you're in the devenv shell."; \
		exit 1; \
	fi

# Clean generated files
clean:
	@echo "Cleaning generated files..."
	rm -rf .luacov
	rm -f luacov.*.out

# Install dependencies
install:
	@echo "Installing dependencies..."
	@if command -v luarocks >/dev/null 2>&1; then \
		luarocks install --local busted; \
		luarocks install --local nlua; \
	else \
		echo "Warning: luarocks not found. Dependencies may need manual installation."; \
	fi
	@if ! command -v stylua >/dev/null 2>&1; then \
		echo "Warning: stylua not found. Install with: cargo install stylua"; \
	fi

# Run pre-commit hooks on all files
pre-commit:
	@echo "Running pre-commit hooks on all files..."
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit run --all-files; \
	else \
		echo "Error: pre-commit not installed. Install with: pip install pre-commit"; \
		exit 1; \
	fi