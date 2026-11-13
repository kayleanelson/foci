SOURCES := Package.swift Sources Tests

.PHONY: check lint format test build app icon icon-test icon-check

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

icon-test:
	python3 -m unittest discover -s icon -p 'test_*.py'

# Fails if the committed icons drifted from what icon/render.py draws.
icon-check: icon-test
	python3 icon/render.py build/icon-check
	diff -r build/icon-check/AppIcon.icon icon/AppIcon.icon
	diff -r build/icon-check/Glyphs.xcassets icon/Glyphs.xcassets
