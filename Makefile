SOURCES := Package.swift Sources Tests

.PHONY: check lint format test build app icon icon-check

check: lint icon-check test build

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

icon:
	python3 icon/render.py

# Fails if the committed icon drifted from what icon/render.py draws.
icon-check:
	python3 icon/render.py build/icon-check/AppIcon.icon
	diff -r build/icon-check/AppIcon.icon icon/AppIcon.icon
