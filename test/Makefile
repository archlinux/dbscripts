TESTSUITE_FILE:=$(shell mktemp)

test-suite:
	echo "#!/usr/bin/bash" > $(TESTSUITE_FILE)
	echo ". $(CURDIR)/lib/common.sh" >> $(TESTSUITE_FILE)
	cat "$(CURDIR)/test.d"/*.sh >> $(TESTSUITE_FILE)
	echo ". $(CURDIR)/lib/shunit2" >> $(TESTSUITE_FILE)
	chmod +x $(TESTSUITE_FILE)

test: test-suite
	$(TESTSUITE_FILE)

test-coverage: test-suite
	kcov \
		--include-path=$(PWD) \
		--exclude-path=$(PWD)/test,$(PWD)/cron-jobs/makepkg.conf,$(PWD)/config \
		$(COVERAGE_DIR) \
	$(TESTSUITE_FILE)

.PHONY: test-suite test test-coverage
