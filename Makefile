SOURCES := Package.swift Sources Tests

.PHONY: check lint format test build app

check: lint test build

lint:
	swift format lint --strict --recursive $(SOURCES)

format:
	swift format --in-place --recursive $(SOURCES)

test:
	swift test

build:
	swift build

app:
	scripts/bundle.sh
