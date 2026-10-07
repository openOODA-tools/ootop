# ootop v0.2.0 Makefile
#
# Build, verification gate, test suite, and tri-distribution packaging.
#
# Usage:
#   make build       - compile main.oo to dist/ootop
#   make check       - run oodac check on every .oo file
#   make line-cap    - enforce 16-256 line cap on every .oo and .oot (shim-exempt)
#   make file-law    - reject forbidden file extensions and stray docs
#   make academy     - verify every .oo has the 4-element Academy header
#   make density     - enforce at most 8 pages per directory
#   make verify      - run line-cap, file-law, academy, density, and check
#   make test        - run 4-tier QA and MCP integration test suite
#   make bench       - run performance benchmarks
#   make package     - build deb, rpm, and arch packages with checksums
#   make clean       - remove build artifacts

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/ootop

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= 0.2.0

.PHONY: build check line-cap file-law academy density verify clean test bench package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@echo "built $(BIN)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
			continue; \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="py js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		$(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== Tier 1: Core CLI & Batch Execution ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@./$(BIN) -h > /dev/null && echo "PASS: -h"
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@./$(BIN) -v | grep -q "0.2.0" && echo "PASS: -v"
	@OODA_NO_JAIL=1 ./$(BIN) -b | grep -q "ootop 0.2.0" && echo "PASS: batch mode execution"
	@OODA_NO_JAIL=1 ./$(BIN) -b -n 1 > /dev/null && echo "PASS: batch mode -n 1"
	@OODA_NO_JAIL=1 ./$(BIN) -b -n 2 -d 1 > .ooda-cache/b2.txt && echo "PASS: batch iterations"
	@test -z "$$(OODA_NO_JAIL=1 ./$(BIN) -b --no-color | grep "$$(printf '\033')")" && echo "PASS: --no-color suppresses ANSI escapes"
	@OODA_NO_JAIL=1 ./$(BIN) -b -t classic/1982 > /dev/null && echo "PASS: -t theme override"
	@OODA_NO_JAIL=1 OO_COLUMNS=50 ./$(BIN) -b | grep -q "ootop 0.2.0" && echo "PASS: compact view on OO_COLUMNS < 60"
	@OODA_NO_JAIL=1 OO_COLUMNS=80 ./$(BIN) -b | grep -q "sovereign top" && echo "PASS: standard view on OO_COLUMNS >= 60"
	@echo "=== Tier 2: MCP Handshake & Protocol Framing ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "2024-11-05" && echo "PASS: MCP initialize protocolVersion"
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q '"name":"ootop","version":"0.2.0"' && echo "PASS: MCP initialize serverInfo"
	@printf '{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP ping"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "system_metrics" && echo "PASS: MCP tools/list system_metrics"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "process_list" && echo "PASS: MCP tools/list process_list"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "systemd_slices" && echo "PASS: MCP tools/list systemd_slices"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "inspect_cgroup_slice" && echo "PASS: MCP tools/list inspect_cgroup_slice"
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "query_process_metrics" && echo "PASS: MCP tools/list query_process_metrics"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP notifications/initialized produces no response"
	@printf '{"jsonrpc":"2.0","id":4,"method":"shutdown","params":{}}\n' | ./$(BIN) --mcp | grep -q '"result":null' && echo "PASS: MCP shutdown"
	@test -z "$$(printf '{"jsonrpc":"2.0","method":"exit","params":{}}\n' | ./$(BIN) --mcp)" && echo "PASS: MCP exit terminates cleanly"
	@test "$$(printf '{"jsonrpc":"2.0","id":1,"method":"ping","params":{}}{"jsonrpc":"2.0","id":2,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -c '"result":{}')" = "2" && echo "PASS: MCP concatenated JSON-RPC messages without newline"
	@printf '{"jsonrpc":"2.0","id":99,"method":"ping","params":{}}' | ./$(BIN) --mcp | grep -q '"id":99' && echo "PASS: MCP request without trailing newline"
	@(sleep 0.1 && printf '{"jsonrpc":"2.0","id":15,"method":"ping","params":{}}\n') | ./$(BIN) --mcp | grep -q '"result":{}' && echo "PASS: MCP stdio idle pause does not crash server"
	@echo "=== Tier 3: All 5 MCP Tools & Data Ingestion ==="
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "cpu" && echo "PASS: MCP system_metrics cpu"
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "memory" && echo "PASS: MCP system_metrics memory"
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "swap" && echo "PASS: MCP system_metrics swap"
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "disk" && echo "PASS: MCP system_metrics disk"
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "network" && echo "PASS: MCP system_metrics network"
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "load_average" && echo "PASS: MCP system_metrics load_average"
	@printf '{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "uptime_seconds" && echo "PASS: MCP system_metrics uptime_seconds"
	@printf '{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"process_list","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "pid" && echo "PASS: MCP process_list default"
	@printf '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"process_list","arguments":{"limit":5,"sort_by":"memory"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "rss_mib" && echo "PASS: MCP process_list sort_by memory"
	@printf '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"process_list","arguments":{"limit":5,"sort_by":"pid"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "pid" && echo "PASS: MCP process_list sort_by pid"
	@printf '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"process_list","arguments":{"limit":5,"sort_by":"comm"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "comm" && echo "PASS: MCP process_list sort_by comm"
	@printf '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"systemd_slices","arguments":{}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "system_slice" && echo "PASS: MCP systemd_slices"
	@printf '{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"inspect_cgroup_slice","arguments":{"slice":"system.slice"}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "system.slice" && echo "PASS: MCP inspect_cgroup_slice"
	@printf '{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"query_process_metrics","arguments":{"pid":1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "threads" && echo "PASS: MCP query_process_metrics"
	@echo "=== Tier 4: Negative Trust & Error Responses ==="
	@printf 'invalid json string\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid json exits -32600"
	@printf '{"jsonrpc":"1.0","id":20,"method":"ping","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP invalid jsonrpc version exits -32600"
	@printf '{"jsonrpc":"2.0","id":21,"method":"","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32600" && echo "PASS: MCP empty method exits -32600"
	@printf '{"jsonrpc":"2.0","id":22,"method":"nonexistent_method","params":{}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown method exits -32601"
	@printf '{"jsonrpc":"2.0","id":23,"method":"tools/call","params":{"name":"nonexistent_tool","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32601" && echo "PASS: MCP unknown tool exits -32601"
	@printf '{"jsonrpc":"2.0","id":24,"method":"tools/call","params":{"arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP missing tool name exits -32602"
	@printf '{"jsonrpc":"2.0","id":25,"method":"tools/call","params":{"name":"process_list","arguments":{"sort_by":"invalid_field"}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP invalid sort_by exits -32602"
	@printf '{"jsonrpc":"2.0","id":26,"method":"tools/call","params":{"name":"inspect_cgroup_slice","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP inspect_cgroup_slice missing slice exits -32602"
	@printf '{"jsonrpc":"2.0","id":27,"method":"tools/call","params":{"name":"query_process_metrics","arguments":{}}}\n' | ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP query_process_metrics missing pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":28,"method":"tools/call","params":{"name":"query_process_metrics","arguments":{"pid":99999999}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP query_process_metrics nonexistent pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":29,"method":"tools/call","params":{"name":"query_process_metrics","arguments":{"pid":-1}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP query_process_metrics negative pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":30,"method":"tools/call","params":{"name":"query_process_metrics","arguments":{"pid":1.5}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP query_process_metrics float pid exits -32602"
	@printf '{"jsonrpc":"2.0","id":31,"method":"tools/call","params":{"name":"query_process_metrics","arguments":{"pid":0}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q -- "-32602" && echo "PASS: MCP query_process_metrics pid 0 exits -32602"
	@printf '{"jsonrpc":"2.0","id":32,"method":"tools/call","params":{"name":"process_list","arguments":{"limit":-5}}}\n' | OODA_NO_JAIL=1 ./$(BIN) --mcp | grep -q "user.slice" && echo "PASS: MCP process_list negative limit fallback"
	@echo "=== Double-Run Determinism & Layout Uniformity ==="
	@run1="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	run2="$$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp)"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism tools/list Run_1 == Run_2"
	@run1="$$(OODA_NO_JAIL=1 ./$(BIN) -b --no-color | grep -E '(ootop|Systemd Slices|Active Processes|PID)' | tr -d '[:space:]')"; \
	run2="$$(OODA_NO_JAIL=1 ./$(BIN) -b --no-color | grep -E '(ootop|Systemd Slices|Active Processes|PID)' | tr -d '[:space:]')"; \
	test "$$run1" = "$$run2" && echo "PASS: determinism batch layout structure Run_1 == Run_2"
	@OODA_NO_JAIL=1 OO_COLUMNS=50 ./$(BIN) -b --no-color | awk '{ if (length != 50) exit 1 }' && echo "PASS: compact layout 50-col rectangular uniformity"
	@OODA_NO_JAIL=1 ./$(BIN) -b --no-color | awk '{ if (length != 81) exit 1 }' && echo "PASS: standard layout 81-col rectangular uniformity"
	@echo "=== Packaging & Installer Smoke Tests ==="
	@./install.sh --dry-run > /dev/null && echo "PASS: install.sh --dry-run"
	@./install.sh --uninstall --dry-run > /dev/null && echo "PASS: install.sh --uninstall --dry-run"
	@./uninstall.sh --dry-run > /dev/null && echo "PASS: uninstall.sh --dry-run"
	@echo "ALL TESTS PASSED"

bench: $(BIN)
	@echo "=== Running ootop performance benchmarks ==="
	@echo "--- Batch mode telemetry snapshot ---"
	@time -p env OODA_NO_JAIL=1 ./$(BIN) -b > /dev/null
	@echo "--- MCP system_metrics invocation ---"
	@time -p sh -c 'printf '\''{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"system_metrics","arguments":{}}}\n'\'' | OODA_NO_JAIL=1 ./$(BIN) --mcp > /dev/null'
	@echo "--- MCP process_list invocation ---"
	@time -p sh -c 'printf '\''{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"process_list","arguments":{"limit":50}}}\n'\'' | OODA_NO_JAIL=1 ./$(BIN) --mcp > /dev/null'
	@echo "--- MCP systemd_slices invocation ---"
	@time -p sh -c 'printf '\''{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"systemd_slices","arguments":{}}}\n'\'' | OODA_NO_JAIL=1 ./$(BIN) --mcp > /dev/null'
	@echo "Benchmark complete."

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/ootop
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/ootop-uninstall
	@echo "installed ootop and ootop-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/ootop $(DESTDIR)$(BINDIR)/ootop-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/ootop $(HOME)/.config/ootop; echo "purged user cache and config"; fi
	@echo "uninstalled ootop and ootop-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/ootop
	@chmod 0755 dist/deb-root/usr/bin/ootop
	@cp uninstall.sh dist/deb-root/usr/bin/ootop-uninstall
	@chmod 0755 dist/deb-root/usr/bin/ootop-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/ootop_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/ootop_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/ootop-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/ootop.spec > ~/rpmbuild/SPECS/ootop.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/ootop.spec
	@cp ~/rpmbuild/RPMS/x86_64/ootop-$(VERSION)*.rpm dist/
	@if ls dist/ootop-$(VERSION)-1.*.x86_64.rpm 1> /dev/null 2>&1; then cp dist/ootop-$(VERSION)-1.*.x86_64.rpm dist/ootop-$(VERSION)-1.x86_64.rpm; fi
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/ootop
	@chmod 0755 dist/arch-pkg/usr/bin/ootop
	@cp uninstall.sh dist/arch-pkg/usr/bin/ootop-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/ootop-uninstall
	@printf "pkgname = ootop\npkgbase = ootop\npkgver = $(VERSION)-1\npkgdesc = Sovereign real-time system monitor with systemd slice grouping and MCP surface\nurl = https://github.com/openOODA-tools/ootop\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = ootop\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/ootop-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD dist/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/ootop-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cp $(BIN) dist/ootop-linux-x86_64
	@chmod 0755 dist/ootop-linux-x86_64
	@(cd dist && sha256sum ootop-linux-x86_64 > ootop-linux-x86_64.sha256)
	@(cd dist && sha256sum ootop* > checksums.txt)
	@echo "built all packages and generated dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
