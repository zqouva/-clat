"""--> [`exe builder`] -- cargo build --release, copy the binary to Releases/."""

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tempfile

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


def target_dir():
    plain = os.path.join(ROOT, "target")
    if os.name != "nt":
        return plain, None
    try:
        ROOT.encode("ascii")
        return plain, None
    except UnicodeEncodeError:
        fallback = os.path.join(tempfile.gettempdir(), "eclat-target")
        print("--> [`eclat`]: this folder path has non-english characters,")
        print("--> [`eclat`]: and the mingw linker chokes on those.")
        print(f"--> [`eclat`]: building in {fallback} instead.")
        return fallback, fallback


def build(env, cleaned):
    if cleaned:
        print("--> [`eclat`]: cleaning first...")
        done = subprocess.run(["cargo", "clean"], cwd=ROOT, env=env)
        if done.returncode != 0:
            fail("cargo clean failed.")
    return subprocess.run(["cargo", "build", "--release"], cwd=ROOT, env=env)


def main():
    parser = argparse.ArgumentParser(prog="build_exe.py")
    parser.add_argument("--clean", action="store_true", help="wipe the target dir before building")
    args = parser.parse_args()

    if shutil.which("cargo") is None:
        fail("cargo not found. install rust from https://rustup.rs first.")

    where, override = target_dir()
    env = None
    if override is not None:
        env = dict(os.environ)
        env["CARGO_TARGET_DIR"] = override

    done = build(env, args.clean)
    if done.returncode != 0 and not args.clean:
        print("--> [`eclat`]: first try failed. retrying from clean...")
        done = build(env, True)
    if done.returncode != 0:
        print("--> [`eclat`]: cargo build failed.")
        print("--> [`eclat`]: close other builds, and check your antivirus")
        print("--> [`eclat`]: is not deleting files inside the target dir.")
        raise SystemExit(1)

    exe = "eclat.exe" if os.name == "nt" else "eclat"
    src = os.path.join(where, "release", exe)
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
