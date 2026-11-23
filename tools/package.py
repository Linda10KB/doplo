"""Build the installable KOReader ZIP with the plugin folder at its root."""
import argparse
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parents[1]
plugin = root / "doplo.koplugin"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--out", type=Path, default=root / "dist")
args = parser.parse_args()
args.out.mkdir(parents=True, exist_ok=True)
meta = (plugin / "_meta.lua").read_text(encoding="utf-8")
version = re.search(r'^\s*version\s*=\s*"([0-9.]+)"', meta, re.MULTILINE).group(1)
target = args.out / f"doplo-v{version}.koplugin.zip"
resources = [path for path in (plugin / "resources").rglob("*") if path.is_file()]
files = sorted((*plugin.rglob("*.lua"), *resources, plugin / "LICENSE", plugin / "README.md", plugin / "SOURCES.md"))
with ZipFile(target, "w") as archive:
    for path in files:
        entry = ZipInfo(path.relative_to(root).as_posix(), (2026, 1, 1, 0, 0, 0))
        entry.create_system = 3
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, path.read_bytes(), ZIP_DEFLATED, compresslevel=9)
with ZipFile(target) as archive:
    assert archive.testzip() is None
    assert "doplo.koplugin/main.lua" in archive.namelist()
    assert "doplo.koplugin/resources/doplo-cover.png" in archive.namelist()
print(target.resolve())
