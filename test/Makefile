TESTSUITE_FILE:=$(shell mktemp)

test-suite:
	echo "#!/usr/bin/bash" > $(TESTSUITE_FILE)
	echo ". /usr/share/makepkg/util/pkgbuild.sh" >> $(TESTSUITE_FILE)
	echo ". $(CURDIR)/lib/common.sh" >> $(TESTSUITE_FILE)
	echo "PATH=$(CURDIR)/../:$(CURDIR)/../cron-jobs/:$(PATH)" >> $(TESTSUITE_FILE)
	cat "$(CURDIR)/test.d"/*.sh >> $(TESTSUITE_FILE)
	echo ". $(CURDIR)/lib/shunit2" >> $(TESTSUITE_FILE)
	chmod +x $(TESTSUITE_FILE)

test: test-suite
	$(TESTSUITE_FILE)

test-coverage: test-suite
	kcov \
		--include-path=$(CURDIR)/../ \
		--exclude-path=$(CURDIR)/../test,$(CURDIR)/../cron-jobs/makepkg.conf,$(CURDIR)/../config \
		$(COVERAGE_DIR) \
	$(TESTSUITE_FILE)

.PHONY: test-suite test test-coverage
