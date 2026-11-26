"""Export the complete Tank OpenAPI schema using default, isolated settings."""

import argparse
import json
import os
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "contracts" / "v1" / "openapi.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    output = parser.parse_args().output.resolve()

    for name in list(os.environ):
        if name.startswith("NOBS_"):
            del os.environ[name]
    with tempfile.TemporaryDirectory() as directory:
        os.chdir(directory)
        from app.main import app

        schema = app.openapi()

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(schema, indent=2, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
