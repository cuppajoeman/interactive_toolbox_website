# Interactive Toolbox Website

A small Jai → Wasm64 → WebGL2 website based on the `mwe_web` site shell.
It currently has two routes:

- `/` — a spinning, GPU-rendered torus
- `/jaide` — a placeholder for the Jaide page

## Build and run

```sh
/home/cjm/projects/jai/bin/jai-linux build.jai
python3 -m http.server 8000 --directory dist
```

Open `http://localhost:8000`. A current browser with WebAssembly Memory64 and
WebGL2 support is required.
