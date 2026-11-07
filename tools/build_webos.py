#!/usr/bin/env python3
"""Build the native webOS TV package for Mappy.

The game is cross-compiled to ARM as a no_std static library (crate
``mappy-native``) and linked into a small SDL2 frontend (``webos/main.c``).
This script assembles the app tree, writes a webOS IPK and, when a base URL is
given, the Homebrew Channel repository files that point at it.

IPK layout (matching ``ares-package`` output):

    debian-binary            "2.0\\n"
    control.tar.gz           ./control
    data.tar.gz
      usr/palm/applications/com.gmaxpwnage.mappy/{mappy,appinfo.json,...}
      usr/palm/packages/com.gmaxpwnage.mappy/packageinfo.json

The outer container is an ``ar`` archive; the inner tarballs are gzip.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
import shutil
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

APP_ID = "com.gmaxpwnage.mappy"
APP_TITLE = "Mappy"
TARGET = "armv7-unknown-linux-gnueabi"
ROOT = Path(__file__).resolve().parents[1]


def workspace_version() -> str:
    """Read ``workspace.package.version`` without a TOML parser."""
    in_workspace = False
    for line in (ROOT / "Cargo.toml").read_text().splitlines():
        line = line.strip()
        if line == "[workspace.package]":
            in_workspace = True
            continue
        if in_workspace:
            if line.startswith("["):
                break
            if line.startswith("version"):
                return line.split("=", 1)[1].strip().strip('"')
    raise SystemExit("could not find workspace version")


def find_sdk(explicit: str | None) -> Path:
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    if os.environ.get("WEBOS_SDK"):
        candidates.append(Path(os.environ["WEBOS_SDK"]))
    candidates.append(ROOT.parent / "webos-sdk" / "arm-webos-linux-gnueabi_sdk-buildroot")
    candidates.append(Path.home() / "webos-sdk" / "arm-webos-linux-gnueabi_sdk-buildroot")
    for candidate in candidates:
        if (candidate / "bin" / "arm-webos-linux-gnueabi-gcc").is_file():
            return candidate
    raise SystemExit(
        "webOS NDK not found; pass --sdk or set WEBOS_SDK "
        "(https://github.com/openlgtv/buildroot-nc4)"
    )


def run(cmd: list[str], **kwargs) -> None:
    print("+", " ".join(str(part) for part in cmd))
    subprocess.run(cmd, check=True, **kwargs)


def build_engine(sdk: Path) -> Path:
    """Build the no_std engine static library for ARM."""
    env = os.environ.copy()
    # Features must not be unified with the std build: always ask for the
    # no-default-features variant of this package alone.
    linker = env.get("WEBOS_LINKER") or str(sdk / "bin" / "arm-webos-linux-gnueabi-gcc")
    env["CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABI_LINKER"] = linker

    # The TV's Cortex-A9/A12-class core needs the VFP (the source's APU mixes
    # floats and soft-float libcalls dominate), Thumb-2 for code density, and
    # fat LTO so the 16k translated instruction functions inline across crates.
    # NEON is left off: VFP3 is present on every webOS TV, NEON is not on A8.
    tuned = (
        "-C target-cpu=cortex-a9 "
        "-C target-feature=+vfp3,-neon,-soft-float,+thumb-mode"
    )
    existing = env.get("CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABI_RUSTFLAGS", "")
    env["CARGO_TARGET_ARMV7_UNKNOWN_LINUX_GNUEABI_RUSTFLAGS"] = (existing + " " + tuned).strip()
    env["CARGO_PROFILE_RELEASE_LTO"] = env.get("CARGO_PROFILE_RELEASE_LTO", "fat")
    cargo = env.get("CARGO", "cargo")
    run(
        [
            cargo,
            "build",
            "--release",
            "--locked",
            "-p",
            "mappy-native",
            "--no-default-features",
            "--target",
            TARGET,
        ],
        cwd=ROOT,
        env=env,
    )
    lib = ROOT / "target" / TARGET / "release" / "libmappy_native.a"
    if not lib.is_file():
        raise SystemExit(f"engine archive missing: {lib}")
    return lib


def build_frontend(sdk: Path, lib: Path, stage: Path) -> Path:
    cc = os.environ.get("WEBOS_CC") or str(sdk / "bin" / "arm-webos-linux-gnueabi-gcc")
    binary = stage / "usr" / "palm" / "applications" / APP_ID / "mappy"
    binary.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            cc,
            "-O2",
            "-march=armv7-a",
            "-mfloat-abi=softfp",
            "-mfpu=neon-fp16",
            "-no-pie",
            "-static-libgcc",
            "-I",
            str(ROOT / "webos"),
            str(ROOT / "webos" / "main.c"),
            "-L",
            str(lib.parent),
            "-lmappy_native",
            "-lSDL2",
            "-lm",
            "-ldl",
            "-lpthread",
            "-lrt",
            "-o",
            str(binary),
        ]
    )
    binary.chmod(0o755)
    return binary


def make_tar_gz(path: Path, entries: list[tuple[Path | bytes, str, int]]) -> None:
    """Write a reproducible gzip-compressed tar.

    ``entries`` holds (source, archive name, mode); a bytes source means a
    generated file. Directories are added explicitly, like ares-package does.
    """
    data = io.BytesIO()
    with tarfile.open(fileobj=data, mode="w", format=tarfile.GNU_FORMAT) as tar:
        for source, name, mode in entries:
            info = tarfile.TarInfo(name)
            info.mtime = 0
            info.uid = info.gid = 0
            info.uname = info.gname = ""
            info.mode = mode
            if isinstance(source, bytes):
                info.size = len(source)
                tar.addfile(info, io.BytesIO(source))
            elif source.is_dir():
                info.type = tarfile.DIRTYPE
                tar.addfile(info)
            else:
                info.size = source.stat().st_size
                with source.open("rb") as handle:
                    tar.addfile(info, handle)
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, compresslevel=9) as gz:
            gz.write(data.getvalue())


def write_ar(path: Path, members: list[tuple[str, bytes]]) -> None:
    """Write a POSIX ar archive (the outer webOS IPK container)."""
    with path.open("wb") as out:
        out.write(b"!<arch>\n")
        for name, payload in members:
            if len(name) > 16:
                raise ValueError(f"ar member name too long: {name}")
            header = (
                f"{name:<16}"
                f"{0:<12}"
                f"{0:<6}"
                f"{0:<6}"
                f"{'100644':<8}"
                f"{len(payload):<10}"
                "`\n"
            ).encode("ascii")
            if len(header) != 60:
                raise AssertionError(f"bad ar header length {len(header)}")
            out.write(header)
            out.write(payload)
            if len(payload) & 1:
                out.write(b"\n")


def copy_app_files(stage: Path, version: str) -> None:
    app_dir = stage / "usr" / "palm" / "applications" / APP_ID
    app_dir.mkdir(parents=True, exist_ok=True)

    appinfo = (ROOT / "webos" / "appinfo.json").read_text().replace("__VERSION__", version)
    json.loads(appinfo)  # fail early on a broken template
    (app_dir / "appinfo.json").write_text(appinfo)

    for name in ("icon.png", "icon_large.png", "splash.png"):
        shutil.copyfile(ROOT / "webos" / "assets" / name, app_dir / name)

    package_dir = stage / "usr" / "palm" / "packages" / APP_ID
    package_dir.mkdir(parents=True, exist_ok=True)
    (package_dir / "packageinfo.json").write_text(
        json.dumps({"id": APP_ID, "version": version, "app": APP_ID}, indent=2) + "\n"
    )


def build_ipk(stage: Path, out_dir: Path, version: str) -> Path:
    app_dir = stage / "usr" / "palm" / "applications" / APP_ID
    control = (
        f"Package: {APP_ID}\n"
        f"Version: {version}\n"
        "Section: misc\n"
        "Priority: optional\n"
        "Architecture: arm\n"
        f"Installed-Size: {sum(p.stat().st_size for p in app_dir.rglob('*') if p.is_file())}\n"
        "Maintainer: gmaxpwnage <me@gavinpower.dev>\n"
        f"Description: {APP_TITLE} for webOS TV\n"
        "webOS-Package-Format-Version: 2\n"
        "webOS-Packager-Version: x.y.x\n"
    ).encode()

    control_tar = out_dir / "control.tar.gz"
    make_tar_gz(control_tar, [(control, "control", 0o644)])

    data_entries: list[tuple[Path | bytes, str, int]] = []
    for name in ("usr", "usr/palm", "usr/palm/applications", "usr/palm/packages"):
        data_entries.append((stage / name, name, 0o755))
    data_entries.append((app_dir, f"usr/palm/applications/{APP_ID}", 0o755))
    for child in sorted(app_dir.iterdir()):
        mode = 0o755 if child.name == "mappy" else 0o644
        data_entries.append((child, f"usr/palm/applications/{APP_ID}/{child.name}", mode))
    package_dir = stage / "usr" / "palm" / "packages" / APP_ID
    data_entries.append((package_dir, f"usr/palm/packages/{APP_ID}", 0o755))
    data_entries.append(
        (package_dir / "packageinfo.json", f"usr/palm/packages/{APP_ID}/packageinfo.json", 0o644)
    )

    data_tar = out_dir / "data.tar.gz"
    make_tar_gz(data_tar, data_entries)

    ipk = out_dir / f"{APP_ID}_{version}_arm.ipk"
    write_ar(
        ipk,
        [
            ("debian-binary", b"2.0\n"),
            ("control.tar.gz", control_tar.read_bytes()),
            ("data.tar.gz", data_tar.read_bytes()),
        ],
    )
    control_tar.unlink()
    data_tar.unlink()
    return ipk


def run_selftest(sdk: Path, lib: Path) -> None:
    """Build the headless ARM engine test and, if qemu is available, run it.

    The hash below is the reference value produced by the x86_64 build; it
    covers 600 frames of video and audio, so a codegen or ABI mistake that
    changes one pixel or sample fails the build.
    """
    expected = "frames=600 hash=88de4d1a16429e1d"
    cc = os.environ.get("WEBOS_CC") or str(sdk / "bin" / "arm-webos-linux-gnueabi-gcc")
    with tempfile.TemporaryDirectory() as tmp:
        binary = Path(tmp) / "engine_selftest_arm"
        run([
            cc, "-O2", "-march=armv7-a", "-mfloat-abi=softfp", "-mfpu=neon-fp16",
            "-static", "-I", str(ROOT / "webos"),
            str(ROOT / "webos" / "engine_selftest.c"),
            "-L", str(lib.parent), "-lmappy_native", "-lm", "-ldl", "-lpthread",
            "-o", str(binary),
        ])
        qemu = os.environ.get("QEMU_ARM")
        if not qemu:
            print("engine selftest built (set QEMU_ARM=qemu-arm to run it)")
            return
        result = subprocess.run([qemu, str(binary)], capture_output=True, text=True, check=False)
        output = (result.stdout or "").strip()
        print(output)
        if result.returncode != 0 or output != expected:
            raise SystemExit(
                f"engine selftest failed (exit {result.returncode}): expected {expected!r}, got {output!r}"
            )
        print("engine selftest OK (ARM output matches the reference hash)")


def describe(ipk: Path) -> tuple[str, int]:
    payload = ipk.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    print(f"{ipk.name}: {len(payload)} bytes, sha256 {digest}")
    return digest, len(payload)


def verify(ipk: Path, version: str) -> None:
    """Cheap structural checks; CI adds readelf and an on-device launch."""
    payload = ipk.read_bytes()
    if payload[:8] != b"!<arch>\n":
        raise SystemExit("IPK is not an ar archive")
    members: dict[str, bytes] = {}
    offset = 8
    while offset + 60 <= len(payload):
        header = payload[offset : offset + 60]
        offset += 60
        name = header[:16].decode("ascii").rstrip()
        size = int(header[48:58].decode("ascii").strip())
        members[name] = payload[offset : offset + size]
        offset += size + (size & 1)
    for required in ("debian-binary", "control.tar.gz", "data.tar.gz"):
        if required not in members:
            raise SystemExit(f"IPK missing {required}")
    if members["debian-binary"] != b"2.0\n":
        raise SystemExit("bad debian-binary")
    with tarfile.open(fileobj=io.BytesIO(members["data.tar.gz"]), mode="r:gz") as tar:
        names = tar.getnames()
        appinfo_name = f"usr/palm/applications/{APP_ID}/appinfo.json"
        if appinfo_name not in names:
            raise SystemExit("appinfo.json not in data.tar.gz")
        appinfo = json.loads(tar.extractfile(appinfo_name).read())
        if appinfo.get("type") != "native":
            raise SystemExit("appinfo type is not native")
        if appinfo.get("version") != version:
            raise SystemExit(f"appinfo version {appinfo.get('version')} != {version}")
        main = appinfo["main"]
        binary_name = f"usr/palm/applications/{APP_ID}/{main}"
        if binary_name not in names:
            raise SystemExit(f"{binary_name} not in data.tar.gz")
        binary = tar.extractfile(binary_name).read(20)
        if binary[:4] != b"\x7fELF" or binary[4] != 1:
            raise SystemExit("main is not a 32-bit ELF")
        if struct.unpack_from("<H", binary, 18)[0] != 40:
            raise SystemExit("main is not ARM")
        if not tar.getmember(binary_name).mode & stat.S_IXUSR:
            raise SystemExit("main is not executable")
    print("IPK structure OK")


def homebrew_repo(out_dir: Path, ipk: Path, version: str, base_url: str, sha: str, size: int) -> None:
    base = base_url.rstrip("/")
    icon160 = out_dir / "icon160.png"
    icon320 = out_dir / "icon320.png"
    screenshot = out_dir / "screenshot.png"
    for source, dest in (
        (ROOT / "webos" / "assets" / "icon160.png", icon160),
        (ROOT / "webos" / "assets" / "icon320.png", icon320),
        (ROOT / "screenshots" / "00-title.png", screenshot),
    ):
        if source.resolve() != dest.resolve():
            shutil.copyfile(source, dest)

    appinfo = json.loads(
        (ROOT / "webos" / "appinfo.json").read_text().replace("__VERSION__", version)
    )
    manifest = {
        "id": APP_ID,
        "version": version,
        "type": "native",
        "title": APP_TITLE,
        "appDescription": appinfo["appDescription"],
        "iconUri": f"{base}/icon320.png",
        "sourceUrl": "https://github.com/gmaxpwnage/mappy-rust",
        "rootRequired": False,
        "ipkUrl": f"{base}/{ipk.name}",
        "ipkHash": {"sha256": sha},
        "ipkSize": size,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")

    repo = {
        "packages": [
            {
                "id": APP_ID,
                "title": APP_TITLE,
                "shortDescription": (
                    "Namco's 1984 arcade classic, recompiled to Rust. Native webOS TV build."
                )[:80],
                "iconUri": f"{base}/icon160.png",
                "detailIconUri": f"{base}/icon320.png",
                "manifestUrl": f"{base}/manifest.json",
                "manifest": manifest,
                "pool": "main",
                "requirements": {"webosRelease": ">=4.0"},
                "screenshots": [{"url": f"{base}/screenshot.png", "caption": "Title screen"}],
            }
        ]
    }
    (out_dir / "apps.json").write_text(json.dumps(repo, indent=2) + "\n")
    print(f"Homebrew repository: {base}/apps.json")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", help="path to the webOS NDK (buildroot-nc4)")
    parser.add_argument("--out", default=str(ROOT / "dist" / "webos"), help="output directory")
    parser.add_argument("--version", default=None, help="package version (default: Cargo.toml)")
    parser.add_argument(
        "--base-url",
        default=None,
        help="public URL of the output directory; also writes manifest.json and apps.json",
    )
    parser.add_argument("--skip-build", action="store_true", help="reuse an existing staging tree")
    parser.add_argument("--selftest", action="store_true", help="build and (if QEMU_ARM is set) run the engine test")
    args = parser.parse_args()

    sdk = find_sdk(args.sdk)
    version = args.version or workspace_version()
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in ("*.ipk", "apps.json", "manifest.json", "icon160.png", "icon320.png", "screenshot.png"):
        for path in out_dir.glob(stale):
            path.unlink()
    stage = out_dir / "stage"
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir(parents=True)

    copy_app_files(stage, version)
    if args.skip_build:
        if not (stage / "usr/palm/applications" / APP_ID / "mappy").is_file():
            raise SystemExit("--skip-build needs an existing staged mappy binary")
    else:
        lib = build_engine(sdk)
        build_frontend(sdk, lib, stage)
        if args.selftest:
            run_selftest(sdk, lib)

    ipk = build_ipk(stage, out_dir, version)
    verify(ipk, version)
    digest, size = describe(ipk)
    if args.base_url:
        homebrew_repo(out_dir, ipk, version, args.base_url, digest, size)

    shutil.rmtree(stage)
    # Keep the output directory tidy: only release-relevant files remain.
    print(f"package: {ipk}")


if __name__ == "__main__":
    main()
