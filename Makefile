.PHONY: install run test lint

install:
	python3 scripts/dev.py setup

run:
	python3 scripts/dev.py run

test:
	python3 scripts/dev.py test

lint:
	python3 scripts/dev.py lint
