.PHONY: fmt setup
fmt:
	find . -name "*.gno" -type f -exec gofumpt -w {} \;

setup:
	python3 setup.py
