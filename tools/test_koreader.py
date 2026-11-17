"""Run real KOReader/SDL with a disposable profile. Requires a Linux KOReader build."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("koreader", type=Path, help="Directory containing reader.lua and luajit")
parser.add_argument("--zip", type=Path, help="Install this release ZIP instead of the source tree")
parser.add_argument("--screens", type=Path, help="Save framebuffer PNGs in this directory")
args = parser.parse_args()
reader = args.koreader.resolve()
with tempfile.TemporaryDirectory(prefix="doplo-smoke-") as tmp:
    profile = Path(tmp)
    plugins = profile / "plugins"
    plugins.mkdir()
    if args.zip:
        with zipfile.ZipFile(args.zip) as z:
            for name in z.namelist():
                path = Path(name)
                assert path.parts[0] == "doplo.koplugin" and ".." not in path.parts
            z.extractall(plugins)
    else:
        shutil.copytree(root / "doplo.koplugin", plugins / "doplo.koplugin")
    (profile / "patches").mkdir()
    shutil.copyfile(root / "tests/ko_smoke.lua", profile / "patches/2-doplo-test.lua")
    (profile / "settings.reader.lua").write_text('return {language="en",color_rendering=true,flash_ui=false}\n')
    (profile / "books").mkdir()
    screens = args.screens.resolve() if args.screens else profile / "screens"
    screens.mkdir(exist_ok=True, parents=True)
    env = dict(os.environ, KO_HOME=tmp, DOPLO_SOURCE=str(root), DOPLO_SCREENS=str(screens),
               SDL_VIDEODRIVER="dummy", SDL_RENDER_DRIVER="software", SDL_AUDIODRIVER="dummy")
    subprocess.run([str(reader / "luajit"), str(root / "tests/storage.lua")],
                   cwd=reader, env=env, check=True, timeout=45)
    for phase, wh in [("play", (1264, 1680)), ("reopen", (800, 600)), ("reader", (600, 800))]:
        env.update(DOPLO_PHASE=phase, EMULATE_READER_W=str(wh[0]), EMULATE_READER_H=str(wh[1]))
        path = profile / "books"
        if phase == "reader":
            path = path / "test.txt"
            path.write_text("Doplo integration test\n" * 20)
        result = subprocess.run([str(reader / "luajit"), "reader.lua", str(path)],
                                cwd=reader, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                text=True, timeout=50)
        if result.returncode or "DOPLO PASS " + phase not in result.stdout:
            raise SystemExit(result.stdout)
        print(next(line for line in result.stdout.splitlines() if line.startswith("DOPLO PASS")))
