# Single source of truth for the Godot version (setup_env.sh receives it via env).
GODOT_VERSION ?= 4.7.2-stable
# gdUnit4: no v7 tags exist yet (latest v6.2.2); master is v7.0.0 and needs Godot 4.7+. Pin a v7.x tag once released.
GDUNIT_REF ?= master
PROJECT := game
ROOT := $(CURDIR)

# Prefer repo-local binary, fall back to godot from PATH.
ifneq ($(wildcard $(ROOT)/.tools/godot),)
GODOT_BIN ?= $(ROOT)/.tools/godot
else ifneq ($(shell command -v godot 2>/dev/null),)
GODOT_BIN ?= $(shell command -v godot)
else
GODOT_BIN ?= $(ROOT)/.tools/godot
endif

export GODOT_VERSION GDUNIT_REF

.PHONY: setup test lint playtest sim export-check check screenshots screenshots-smoke

setup:
	bash tools/setup_env.sh

test:
	mkdir -p $(PROJECT)/test/reports
	$(GODOT_BIN) --headless --path $(PROJECT) -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -a res://test/unit -rd res://test/reports -c

lint:
	gdlint $(PROJECT)/src $(PROJECT)/test && gdformat --check $(PROJECT)/src $(PROJECT)/test

playtest:
	mkdir -p $(PROJECT)/test/reports
	$(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --rounds=200 --seed=42 \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest.json && \
	$(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --random --rounds=200 --seed=42 \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest_random.json

sim:
	python3 tools/balance_sim.py

# Real Android export needs the Android SDK; on machines without it we only
# validate presets and check that the project loads (--quit).
export-check:
	python3 tools/validate_presets.py $(PROJECT)/export_presets.cfg
	$(GODOT_BIN) --headless --path $(PROJECT) --quit
	@if [ -n "$$ANDROID_HOME$$ANDROID_SDK_ROOT" ]; then \
		mkdir -p /tmp/export-check; \
		$(GODOT_BIN) --headless --path $(PROJECT) --export-debug Android /tmp/export-check/game.apk || true; \
	fi

check: lint test export-check

screenshots:
	bash tools/gen_screenshots.sh --store

screenshots-smoke:
	bash tools/gen_screenshots.sh
