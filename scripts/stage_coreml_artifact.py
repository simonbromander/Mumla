#!/usr/bin/env python3
import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


COMPONENTS = [
    "Preprocessor",
    "Encoder",
    "Decoder",
    "JointDecisionv3",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compile a portable Pianissimo CoreML artifact into FluidAudio's local model layout."
    )
    parser.add_argument("source", type=Path, help="Directory containing *.mlpackage folders and parakeet_vocab.json.")
    parser.add_argument("output", type=Path, help="Output directory for compiled *.mlmodelc folders.")
    parser.add_argument("--force", action="store_true", help="Replace an existing output directory.")
    return parser.parse_args()


def require_file(path: Path) -> None:
    if not path.exists():
        raise SystemExit(f"Missing required file: {path}")


def require_xcrun() -> None:
    if shutil.which("xcrun") is None:
        raise SystemExit("xcrun is required to compile CoreML packages.")


def compile_component(source: Path, staging: Path, name: str) -> None:
    package = source / f"{name}.mlpackage"
    require_file(package / "Manifest.json")
    require_file(package / "Data" / "com.apple.CoreML" / "model.mlmodel")

    subprocess.run(
        ["xcrun", "coremlcompiler", "compile", str(package), str(staging)],
        check=True,
    )

    compiled = staging / f"{name}.mlmodelc"
    if not compiled.exists():
        raise SystemExit(f"CoreML compile succeeded but did not create {compiled}")


def main() -> int:
    args = parse_args()
    source = args.source.resolve()
    output = args.output.resolve()

    require_xcrun()
    require_file(source / "parakeet_vocab.json")

    if output.exists() and any(output.iterdir()) and not args.force:
        raise SystemExit(f"Output directory is not empty: {output}. Use --force to replace it.")

    with tempfile.TemporaryDirectory(prefix="mumla-coreml-stage-") as temporary:
        staging = Path(temporary) / "compiled"
        staging.mkdir(parents=True)

        for component in COMPONENTS:
            print(f"Compiling {component}.mlpackage", flush=True)
            compile_component(source, staging, component)

        shutil.copy2(source / "parakeet_vocab.json", staging / "parakeet_vocab.json")

        license_file = source / "LICENSE-and-attribution.txt"
        if license_file.exists():
            shutil.copy2(license_file, staging / "LICENSE-and-attribution.txt")

        if output.exists():
            backup = output.with_name(f"{output.name}.replace")
            if backup.exists():
                shutil.rmtree(backup)
            output.rename(backup)
            try:
                shutil.move(str(staging), str(output))
            except Exception:
                backup.rename(output)
                raise
            shutil.rmtree(backup)
        else:
            output.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(staging), str(output))

    print(f"Compiled model staged at {output}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
