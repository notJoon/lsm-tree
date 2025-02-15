.PHONY: fmt setup test-docker
fmt:
	find . -name "*.gno" -type f -exec gofumpt -w {} \;

setup:
	python3 setup.py

test-docker:
	docker build -t lsm-test .
	docker run --rm lsm-test
