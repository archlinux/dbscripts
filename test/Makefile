PACKAGE_CACHE:=$(shell mktemp -d)

test:
	PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH) PACKAGE_CACHE=$(PACKAGE_CACHE) bats test.d

test-coverage:
	PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH) PACKAGE_CACHE=$(PACKAGE_CACHE) kcov \
		--include-path=$(CURDIR)/../ \
		--exclude-path=$(CURDIR)/../test,$(CURDIR)/../cron-jobs/makepkg.conf,$(CURDIR)/../config \
		$(COVERAGE_DIR) \
		bats test.d

.PHONY: test test-coverage
