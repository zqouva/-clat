"""--> [`exe builder`] -- cargo build --release, copy the binary to Releases/."""

import argparse
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
    parser = argparse.ArgumentParser(prog="build_exe.py")
    parser.add_argument("--clean", action="store_true", help="wipe target/ before building")
    args = parser.parse_args()

    if os.name == "nt":
        try:
            ROOT.encode("ascii")
        except UnicodeEncodeError:
            print("--> [`eclat`]: warning: this folder path has non-english characters.")
            print("--> [`eclat`]: warning: the mingw linker chokes on those. if linking fails,")
            print("--> [`eclat`]: warning: move the project to something plain like C:\\Code\\Eclat")

    if shutil.which("cargo") is None:
        fail("cargo not found. install rust from https://rustup.rs first.")
    if args.clean:
        print("--> [`eclat`]: cleaning target/...")
        done = subprocess.run(["cargo", "clean"], cwd=ROOT)
        if done.returncode != 0:
            fail("cargo clean failed.")
    done = subprocess.run(["cargo", "build", "--release"], cwd=ROOT)
    if done.returncode != 0:
        print("--> [`eclat`]: cargo build failed.")
        print("--> [`eclat`]: try: python3 build_exe.py --clean")
        print("--> [`eclat`]: if it still fails, move the project to an english-only path,")
        print("--> [`eclat`]: close other builds, and check your antivirus is not eating target/.")
        raise SystemExit(1)

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
