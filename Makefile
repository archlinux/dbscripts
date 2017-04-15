test-image:
	docker build --pull -t dbscripts/test test

test: test-image
	docker run --rm --network=none -v $(PWD):/dbscripts:ro --tmpfs=/tmp:exec -w /dbscripts/test dbscripts/test ./runTest

.PHONY: test-image test
