CASES ?= cases
BATS_ARGS ?=

test:
	BUILDDIR=/build PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH) bats $(BATS_ARGS) $(CASES)

test-coverage:
	BUILDDIR=/build PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH) kcov \
		--include-path=$(CURDIR)/../ \
		--exclude-path=$(CURDIR)/../test,$(CURDIR)/../cron-jobs/makepkg.conf,$(CURDIR)/../config \
		$(COVERAGE_DIR) \
		bats $(CASES)

.PHONY: test test-coverage
