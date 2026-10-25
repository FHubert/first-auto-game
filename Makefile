# Single source of truth for the Godot version (setup_env.sh receives it via env).
GODOT_VERSION ?= 4.7.2-stable
# gdUnit4: no v7 tags exist yet (latest v6.2.2); master is v7.0.0 and needs Godot 4.7+. Pin a v7.x tag once released.
GDUNIT_REF ?= master
PROJECT := game
ROOT := $(CURDIR)
# make test/playtest: XDG_DATA_HOME gives each checkout its own user:// dir (Godot on Linux),
# so parallel worktrees do not share ~/.local/share/godot/app_userdata (SaveSystem rename failures).

# Prefer repo-local binary, fall back to godot from PATH.
ifneq ($(wildcard $(ROOT)/.tools/godot),)
GODOT_BIN ?= $(ROOT)/.tools/godot
else ifneq ($(shell command -v godot 2>/dev/null),)
GODOT_BIN ?= $(shell command -v godot)
else
GODOT_BIN ?= $(ROOT)/.tools/godot
endif

export GODOT_VERSION GDUNIT_REF

.PHONY: setup test test-tools lint playtest sim export-check check perf screenshots screenshots-smoke

setup:
	bash tools/setup_env.sh

# T-255: pelne wyjscie (stdout+stderr) idzie na konsole i do test_output.log; kod wyjscia gdUnit zachowany
# (POSIX sh, bez pipefail); potem budzet sygnatur ERROR (tools/log_budget.py + log_budget_allow.txt).
test:
	mkdir -p $(PROJECT)/test/reports $(ROOT)/.godot-userdata
	( XDG_DATA_HOME=$(ROOT)/.godot-userdata $(GODOT_BIN) --headless --path $(PROJECT) -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -a res://test/unit -rd res://test/reports -c 2>&1; echo $$? > $(PROJECT)/test/reports/test_exit ) \
		| tee $(PROJECT)/test/reports/test_output.log; \
	rc=$$(cat $(PROJECT)/test/reports/test_exit); \
	python3 tools/log_budget.py $(PROJECT)/test/reports/test_output.log --allow tools/log_budget_allow.txt || exit 1; \
	exit $$rc

test-tools:
	python3 -m unittest discover -s tools -p "test_*.py"

lint:
	gdlint $(PROJECT)/src $(PROJECT)/test && gdformat --check $(PROJECT)/src $(PROJECT)/test

PLAYTEST_SEED ?= 42

playtest:
	mkdir -p $(PROJECT)/test/reports $(ROOT)/.godot-userdata
	XDG_DATA_HOME=$(ROOT)/.godot-userdata $(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --rounds=200 --seed=$(PLAYTEST_SEED) \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest.json && \
	XDG_DATA_HOME=$(ROOT)/.godot-userdata $(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --random --rounds=200 --seed=$(PLAYTEST_SEED) \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest_random.json && \
	XDG_DATA_HOME=$(ROOT)/.godot-userdata $(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --greedy --campaign --rounds=200 --seed=$(PLAYTEST_SEED) \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest_greedy.json && \
	XDG_DATA_HOME=$(ROOT)/.godot-userdata $(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --greedy --campaign --stay --rounds=400 --seed=$(PLAYTEST_SEED) \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest_greedy_stay.json && \
	XDG_DATA_HOME=$(ROOT)/.godot-userdata $(GODOT_BIN) --headless --path $(PROJECT) -- --playtest --assist --rounds=400 --seed=$(PLAYTEST_SEED) \
		--report=$(ROOT)/$(PROJECT)/test/reports/playtest_assist.json

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

check: lint test test-tools export-check

# T-241: stala baza wydajnosci (CI, nie urzadzenie) -> game/test/reports/perf.json. Poza `check` (kilka minut).
PERF_TMP := $(PROJECT)/test/reports/perf
PERF_RUN = XDG_DATA_HOME=$(ROOT)/.godot-userdata timeout 900 $(GODOT_BIN) --headless --path $(PROJECT) --script

perf:
	mkdir -p $(PERF_TMP) $(ROOT)/.godot-userdata
	$(PERF_RUN) res://test/perf/measure_startup.gd -- --out test/reports/perf/startup.json
	$(PERF_RUN) res://test/perf/measure_hint.gd -- --out test/reports/perf/hint.json
	$(PERF_RUN) res://test/perf/measure_prefetch.gd -- --out test/reports/perf/prefetch.json
	python3 tools/perf_merge.py --startup $(PERF_TMP)/startup.json --hint $(PERF_TMP)/hint.json \
		--prefetch $(PERF_TMP)/prefetch.json --out $(PROJECT)/test/reports/perf.json \
		--commit "$$(git rev-parse --short HEAD)" --godot-version "$(GODOT_VERSION)"
	# T-260: bramka progow
	python3 tools/perf_gate.py --perf $(PROJECT)/test/reports/perf.json

screenshots:
	bash tools/gen_screenshots.sh --store

screenshots-smoke:
	bash tools/gen_screenshots.sh
