SOURCES := Package.swift Sources Tests

.PHONY: check lint format test build app icon icon-test icon-check brand brand-check

check: lint brand-check icon-check test build

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

BRAND := ../branding/palette.json

# Copies the shared branding palette in, so the build never needs the branding folder.
brand:
	cp $(BRAND) icon/brand.json

# Fails if branding changed since the last make brand; skipped where branding is absent.
brand-check:
	@if [ -f $(BRAND) ]; then cmp -s $(BRAND) icon/brand.json || { echo "branding changed: run make brand && make icon"; exit 1; }; else echo "no $(BRAND); skipping"; fi

icon-test:
	python3 -m unittest discover -s icon -p 'test_*.py'

# Fails if the committed icons drifted from what icon/render.py draws.
icon-check: icon-test
	python3 icon/render.py build/icon-check
	diff -r build/icon-check/AppIcon.icon icon/AppIcon.icon
	diff -r build/icon-check/Glyphs.xcassets icon/Glyphs.xcassets
