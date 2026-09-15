const canvas = document.querySelector("#canvas");
const gl = canvas.getContext("webgl2", { antialias: true });

if (!gl) {
    throw new Error("This example requires WebGL2.");
}

let wasmMemory;
let jaiContext = 0n;
let assetPackageBytes;
let selectedPageFromWasm = 0;
const pendingPointerSamples = [];

// WebGL resources are JavaScript objects, which cannot live directly in Wasm
// memory. Jai sees small u32 handles; this table maps them back to JS objects.
const handles = [null];
const addHandle = object => {
    handles.push(object);
    return handles.length - 1;
};
const fromHandle = handle => handle === 0 ? null : handles[handle];

const memoryView = () => new DataView(wasmMemory.buffer);
const asNumber = value => typeof value === "bigint" ? Number(value) : value;

function readWasmString(pointer, byteLength) {
    const bytes = new Uint8Array(
        wasmMemory.buffer,
        asNumber(pointer),
        asNumber(byteLength),
    );
    return new TextDecoder().decode(bytes);
}

function readWasmCString(pointer) {
    const bytes = new Uint8Array(wasmMemory.buffer);
    const start = asNumber(pointer);
    let end = start;
    while (bytes[end] !== 0) end += 1;
    return new TextDecoder().decode(bytes.subarray(start, end));
}

const imports = {
    wasm_set_context(contextPointer) {
        jaiContext = contextPointer;
    },

    web_asset_package_size() {
        return BigInt(assetPackageBytes?.byteLength ?? 0);
    },

    web_copy_asset_package(destination, size) {
        const byteLength = asNumber(size);
        if (!assetPackageBytes || byteLength !== assetPackageBytes.byteLength) return 0;
        new Uint8Array(wasmMemory.buffer, asNumber(destination), byteLength).set(assetPackageBytes);
        return 1;
    },

    memcmp(leftPointer, rightPointer, count) {
        const bytes = new Uint8Array(wasmMemory.buffer);
        const left = asNumber(leftPointer);
        const right = asNumber(rightPointer);
        const length = asNumber(count);

        for (let index = 0; index < length; index += 1) {
            const difference = bytes[left + index] - bytes[right + index];
            if (difference !== 0) return difference;
        }
        return 0;
    },

    wasm_write_string(count, data, toStandardError) {
        const message = readWasmString(data, count);
        (toStandardError ? console.error : console.log)(message.trimEnd());
    },

    wasm_debug_break() {
        debugger;
    },

    browser_sync_selected_page(page) {
        selectedPageFromWasm = page;
    },

    glCreateShader(type) {
        return addHandle(gl.createShader(type));
    },

    glShaderSource(shaderHandle, count, stringsPointer, lengthsPointer) {
        const view = memoryView();
        const sources = [];
        const stringsBase = asNumber(stringsPointer);
        const lengthsBase = asNumber(lengthsPointer);

        for (let index = 0; index < count; index += 1) {
            // Jai's Wasm target is wasm64, so pointers stored in memory are u64.
            const stringPointer = view.getBigUint64(stringsBase + index * 8, true);
            const stringLength = view.getInt32(lengthsBase + index * 4, true);
            sources.push(readWasmString(stringPointer, stringLength));
        }

        gl.shaderSource(fromHandle(shaderHandle), sources.join(""));
    },

    glCompileShader(shaderHandle) {
        const shader = fromHandle(shaderHandle);
        gl.compileShader(shader);
        if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
            throw new Error(`Shader compilation failed:\n${gl.getShaderInfoLog(shader)}`);
        }
    },

    glCreateProgram() {
        return addHandle(gl.createProgram());
    },

    glAttachShader(programHandle, shaderHandle) {
        gl.attachShader(fromHandle(programHandle), fromHandle(shaderHandle));
    },

    glLinkProgram(programHandle) {
        const program = fromHandle(programHandle);
        gl.linkProgram(program);
        if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
            throw new Error(`Program link failed:\n${gl.getProgramInfoLog(program)}`);
        }
    },

    glScissor(x, y, width, height) {
        gl.scissor(x, y, width, height);
    },

    glGenVertexArrays(count, arraysPointer) {
        const view = memoryView();
        const base = asNumber(arraysPointer);
        for (let index = 0; index < count; index += 1) {
            view.setUint32(base + index * 4, addHandle(gl.createVertexArray()), true);
        }
    },

    glBindVertexArray(arrayHandle) {
        gl.bindVertexArray(fromHandle(arrayHandle));
    },

    glGenBuffers(count, buffersPointer) {
        const view = memoryView();
        const base = asNumber(buffersPointer);
        for (let index = 0; index < count; index += 1) {
            view.setUint32(base + index * 4, addHandle(gl.createBuffer()), true);
        }
    },

    glBindBuffer(target, bufferHandle) {
        gl.bindBuffer(target, fromHandle(bufferHandle));
    },

    glActiveTexture(texture) {
        gl.activeTexture(texture);
    },

    glBindTexture(target, textureHandle) {
        gl.bindTexture(target, fromHandle(textureHandle));
    },

    glBlendFunc(sourceFactor, destinationFactor) {
        gl.blendFunc(sourceFactor, destinationFactor);
    },

    glBufferData(target, size, dataPointer, usage) {
        const byteLength = asNumber(size);
        const pointer = asNumber(dataPointer);
        if (pointer === 0) {
            gl.bufferData(target, byteLength, usage);
        } else {
            const bytes = new Uint8Array(wasmMemory.buffer, pointer, byteLength);
            gl.bufferData(target, bytes, usage);
        }
    },

    glVertexAttribPointer(index, size, type, normalized, stride, pointer) {
        gl.vertexAttribPointer(index, size, type, normalized !== 0, stride, asNumber(pointer));
    },

    glEnableVertexAttribArray(index) {
        gl.enableVertexAttribArray(index);
    },

    glGetUniformLocation(programHandle, namePointer) {
        const location = gl.getUniformLocation(
            fromHandle(programHandle),
            readWasmCString(namePointer),
        );
        return location === null ? -1 : addHandle(location);
    },

    glUniform1f(locationHandle, value) {
        if (locationHandle >= 0) gl.uniform1f(fromHandle(locationHandle), value);
    },

    glUniform1i(locationHandle, value) {
        if (locationHandle >= 0) gl.uniform1i(fromHandle(locationHandle), value);
    },

    glUniform2f(locationHandle, x, y) {
        if (locationHandle >= 0) gl.uniform2f(fromHandle(locationHandle), x, y);
    },

    glUniform3f(locationHandle, x, y, z) {
        if (locationHandle >= 0) gl.uniform3f(fromHandle(locationHandle), x, y, z);
    },

    glClearColor(red, green, blue, alpha) {
        gl.clearColor(red, green, blue, alpha);
    },

    glClear(mask) {
        gl.clear(mask);
    },

    glEnable(capability) {
        gl.enable(capability);
    },

    glDisable(capability) {
        gl.disable(capability);
    },

    glCullFace(mode) {
        gl.cullFace(mode);
    },

    glFrontFace(mode) {
        gl.frontFace(mode);
    },

    glUseProgram(programHandle) {
        gl.useProgram(fromHandle(programHandle));
    },

    glDrawElements(mode, count, type, offset) {
        gl.drawElements(mode, count, type, asNumber(offset));
    },

    glViewport(x, y, width, height) {
        gl.viewport(x, y, width, height);
    },
};

const environment = {
    env: new Proxy(imports, {
        get(target, property) {
            if (Object.hasOwn(target, property)) return target[property];
            return () => { throw new Error(`Missing Wasm import: env.${String(property)}`); };
        },
    }),
};

function resize(instance) {
    const pixelRatio = window.devicePixelRatio || 1;
    const width = Math.max(1, Math.floor(canvas.clientWidth * pixelRatio));
    const height = Math.max(1, Math.floor(canvas.clientHeight * pixelRatio));

    if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
    }

    instance.exports.resize(width, height);
}

async function start() {
    const [wasmResponse, packageResponse] = await Promise.all([
        fetch("main.wasm?v=20260915f"),
        fetch("assets.package?v=20260915f"),
    ]);
    if (!wasmResponse.ok) throw new Error(`Could not load main.wasm (${wasmResponse.status}).`);
    if (!packageResponse.ok) throw new Error(`Could not load assets.package (${packageResponse.status}).`);

    assetPackageBytes = new Uint8Array(await packageResponse.arrayBuffer());
    const { instance } = await WebAssembly.instantiateStreaming(wasmResponse, environment);
    wasmMemory = instance.exports.memory;

    // Jai's exported program entry point has C's (argc, argv) shape. Because
    // argv is a wasm64 pointer, JavaScript passes it as a BigInt.
    instance.exports.main(0, 0n);
    const atlasTextureHandle = await loadTexture("atlas.png?v=20260915f");
    instance.exports.set_msdf_atlas_texture_input(atlasTextureHandle);

    const normalizedPath = () => window.location.pathname.replace(/\/+$/, "") || "/";
    const pageFromPath = () => normalizedPath() === "/jaide" ? 1 : 0;
    const pathFromPage = page => page === 1 ? "/jaide" : "/";
    const setPageMetadata = page => {
        document.title = page === 1 ? "Jaide — Interactive Toolbox" : "Interactive Toolbox";
        const description = document.querySelector('meta[name="description"]');
        if (description) {
            description.content = page === 1
                ? "A practical guide to Jaide setup, editing, navigation, projects, build and run, shortcuts, and configuration."
                : "Interactive Toolbox projects and experiments, built with Jai.";
        }
        canvas.setAttribute(
            "aria-label",
            page === 1 ? "Jaide page" : "A spinning torus on the Interactive Toolbox home page",
        );
    };

    let currentPage = pageFromPath();
    selectedPageFromWasm = currentPage;
    instance.exports.set_selected_page_input(currentPage);
    setPageMetadata(currentPage);

    window.addEventListener("popstate", () => {
        currentPage = pageFromPath();
        instance.exports.set_selected_page_input(currentPage);
        setPageMetadata(currentPage);
    });

    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    document.documentElement.classList.add("ready");

    const frame = timestamp => {
        resize(instance);
        flushPointerInput(instance);
        instance.exports.draw_frame(jaiContext, (reduceMotion ? 0 : timestamp) * 0.001);

        const selectedPage = selectedPageFromWasm;
        if (selectedPage !== currentPage) {
            currentPage = selectedPage;
            const nextPath = pathFromPage(selectedPage);
            if (normalizedPath() !== nextPath) history.pushState({ page: selectedPage }, "", nextPath);
            setPageMetadata(selectedPage);
        }
        requestAnimationFrame(frame);
    };

    wireInput(instance);
    requestAnimationFrame(frame);
}

async function loadTexture(url) {
    const image = new Image();
    image.src = url;
    await image.decode();

    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.bindTexture(gl.TEXTURE_2D, null);
    return addHandle(texture);
}

function wireInput(instance) {
    const forwardPointer = event => {
        const rect = canvas.getBoundingClientRect();
        const x = (event.clientX - rect.left) * canvas.width / rect.width;
        const y = (event.clientY - rect.top) * canvas.height / rect.height;
        const leftDown = (event.buttons & 1) !== 0;
        const rightDown = (event.buttons & 2) !== 0;
        const sample = { x, y, leftDown, rightDown };
        const previous = pendingPointerSamples.at(-1);

        // Coalesce motion, but retain button transitions. A quick browser
        // click can otherwise press and release between two animation frames,
        // which an immediate-mode UI would never observe.
        if (previous &&
            previous.leftDown === sample.leftDown &&
            previous.rightDown === sample.rightDown) {
            pendingPointerSamples[pendingPointerSamples.length - 1] = sample;
        } else {
            pendingPointerSamples.push(sample);
        }
    };

    canvas.addEventListener("pointerdown", event => {
        forwardPointer(event);
        canvas.setPointerCapture(event.pointerId);
    });

    canvas.addEventListener("pointermove", event => {
        forwardPointer(event);
    });

    const releasePointer = event => {
        forwardPointer(event);
        if (canvas.hasPointerCapture(event.pointerId)) {
            canvas.releasePointerCapture(event.pointerId);
        }
    };
    canvas.addEventListener("pointerup", releasePointer);
    canvas.addEventListener("pointercancel", releasePointer);
    canvas.addEventListener("contextmenu", event => event.preventDefault());

    canvas.addEventListener("wheel", event => {
        event.preventDefault();

        // A wheel event and its pointer position must reach Jai together.
        // Otherwise an older queued click sample can make the immediate-mode
        // UI believe the cursor is outside the scroll region for this frame.
        const rect = canvas.getBoundingClientRect();
        const x = (event.clientX - rect.left) * canvas.width / rect.width;
        const y = (event.clientY - rect.top) * canvas.height / rect.height;
        pendingPointerSamples.length = 0;
        instance.exports.ui_pointer_input(
            x,
            y,
            (event.buttons & 1) !== 0 ? 1 : 0,
            (event.buttons & 2) !== 0 ? 1 : 0,
        );
        instance.exports.ui_scroll_input(-event.deltaY / 100);
    }, { passive: false });
}

function flushPointerInput(instance) {
    if (pendingPointerSamples.length === 0) return;
    const sample = pendingPointerSamples.shift();
    instance.exports.ui_pointer_input(
        sample.x,
        sample.y,
        sample.leftDown ? 1 : 0,
        sample.rightDown ? 1 : 0,
    );
}

start().catch(error => {
    console.error(error);
    const loading = document.querySelector("#loading");
    if (loading) loading.textContent = "INTERACTIVE TOOLBOX COULD NOT START.";
});
