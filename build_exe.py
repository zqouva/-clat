"""--> [`exe builder`] -- cargo build --release, copy the binary to Releases/."""

import os
import platform
import shutil
import subprocess
import sys

print("--> [`eclat`]: building exe...")

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "Releases")


def fail(text):
    print(f"--> [`eclat`]: {text}")
    raise SystemExit(1)


def version():
    with open(os.path.join(ROOT, "Cargo.toml"), encoding="utf-8") as handle:
        for line in handle:
            if line.strip().startswith("version"):
                return line.split("=", 1)[1].strip().strip('"')
    fail("no version in Cargo.toml.")


def main():
    if shutil.which("cargo") is None:
        fail("cargo not found. install rust from https://rustup.rs first.")
    done = subprocess.run(["cargo", "build", "--release"], cwd=ROOT)
    if done.returncode != 0:
        fail("cargo build failed.")

    exe = "eclat.exe" if os.name == "nt" else "eclat"
    src = os.path.join(ROOT, "target", "release", exe)
    if not os.path.isfile(src):
        fail(f"{src} missing after build.")

    osname = {"Windows": "windows", "Linux": "linux", "Darwin": "macos"}.get(platform.system(), "bin")
    arch = {"amd64": "x64", "x86_64": "x64", "arm64": "arm64", "aarch64": "arm64"}.get(
        platform.machine().lower(), platform.machine().lower()
    )
    out = f"eclat-{version()}-{osname}-{arch}{'.exe' if os.name == 'nt' else ''}"
    os.makedirs(OUT_DIR, exist_ok=True)
    dst = os.path.join(OUT_DIR, out)
    shutil.copy2(src, dst)
    print(f"--> [`eclat`]: wrote {dst} ({os.path.getsize(dst)} bytes).")

    check = subprocess.run([dst, "--version"], capture_output=True, text=True)
    if check.returncode != 0:
        fail("exe failed the --version check.")
    print(f"--> [`eclat`]: {check.stdout.strip()} runs.")


if __name__ == "__main__":
    sys.exit(main())
