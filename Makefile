.PHONY: test

test:
	nvim --headless -u NONE -i NONE -n --cmd 'set rtp+=.' -l tests/run.lua

.PHONY: coverage

coverage:
	eval "$$(luarocks --lua-version=5.1 path)" && nvim --headless -u NONE -i NONE -n --cmd 'set rtp+=.' -l tests/coverage.lua

.PHONY: coverage-report

coverage-report:
	nvim --headless -u NONE -i NONE -n --cmd 'set rtp+=.' -l tests/coverage_report.lua
