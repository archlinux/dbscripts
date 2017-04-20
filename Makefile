IMAGE:=dbscripts/test
RUN_OPTIONS:=--rm --network=none -v $(PWD):/dbscripts:ro --tmpfs=/tmp:exec --tmpfs=/build -w /dbscripts/test

test-image:
	docker build --pull -t $(IMAGE) test

test: test-image
	docker run $(RUN_OPTIONS) $(IMAGE) make test

test-coverage: test-image
	rm -rf ${PWD}/coverage
	mkdir -m 777 ${PWD}/coverage
	docker run  $(RUN_OPTIONS) -v ${PWD}/coverage:/coverage -e COVERAGE_DIR=/coverage $(IMAGE) make test-coverage

.PHONY: test-image test test-coverage
