.PHONY: install run test lint format

install:
	python3 scripts/dev.py setup

run:
	python3 scripts/dev.py run

test:
	python3 scripts/dev.py test

lint:
	python3 scripts/dev.py lint

format:
	python3 scripts/dev.py format
