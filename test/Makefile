test:
	PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH) bats cases

test-coverage:
	PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH) kcov \
		--include-path=$(CURDIR)/../ \
		--exclude-path=$(CURDIR)/../test,$(CURDIR)/../cron-jobs/makepkg.conf,$(CURDIR)/../config \
		$(COVERAGE_DIR) \
		bats cases

.PHONY: test test-coverage
