/** Captura estados reproducibles del hero sin modificar preferencias del sistema. */

import { spawn } from "node:child_process";
import { mkdtemp, mkdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const chrome = "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe";
const outputDir = resolve("build", "website-qa");
const profileDir = await mkdtemp(join(tmpdir(), "victoria-web-qa-"));
const port = 9333;

await mkdir(outputDir, { recursive: true });

const processHandle = spawn(chrome, [
  "--headless=new",
  "--disable-gpu",
  "--hide-scrollbars",
  "--no-first-run",
  "--remote-debugging-port=" + port,
  "--user-data-dir=" + profileDir,
  "about:blank",
], { stdio: "ignore" });

const wait = (milliseconds) => new Promise((resolveWait) => setTimeout(resolveWait, milliseconds));

async function waitForDebugger() {
  for (let attempt = 0; attempt < 50; attempt += 1) {
    try {
      const response = await fetch("http://127.0.0.1:" + port + "/json/version");
      if (response.ok) return;
    } catch (_) {
      // Chrome aún está iniciando.
    }
    await wait(100);
  }
  throw new Error("Chrome no abrió el puerto de depuración para la prueba.");
}

await waitForDebugger();
const targetResponse = await fetch(
  "http://127.0.0.1:" + port + "/json/new?http://localhost:4173/index.html",
  { method: "PUT" },
);
const target = await targetResponse.json();
const socket = new WebSocket(target.webSocketDebuggerUrl);

let nextId = 1;
const pending = new Map();

socket.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) return;
  const callbacks = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) callbacks.reject(new Error(message.error.message));
  else callbacks.resolve(message.result);
});

await new Promise((resolveOpen, rejectOpen) => {
  socket.addEventListener("open", resolveOpen, { once: true });
  socket.addEventListener("error", rejectOpen, { once: true });
});

function send(method, params = {}) {
  const id = nextId;
  nextId += 1;
  return new Promise((resolveCommand, rejectCommand) => {
    pending.set(id, { resolve: resolveCommand, reject: rejectCommand });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function capture(width, height, progress, filename) {
  await send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width < 700,
  });
  await send("Emulation.setEmulatedMedia", {
    features: [{ name: "prefers-reduced-motion", value: "no-preference" }],
  });
  await send("Runtime.evaluate", {
    expression: "window.scrollTo(0, (document.querySelector('.book-hero').offsetHeight - window.innerHeight) * " + progress + ")",
  });
  await wait(180);
  const result = await send("Page.captureScreenshot", {
    format: "png",
    captureBeyondViewport: false,
    fromSurface: true,
  });
  await writeFile(join(outputDir, filename), Buffer.from(result.data, "base64"));
}

async function captureCurrent(filename) {
  const result = await send("Page.captureScreenshot", {
    format: "png",
    captureBeyondViewport: false,
    fromSurface: true,
  });
  await writeFile(join(outputDir, filename), Buffer.from(result.data, "base64"));
}

try {
  await send("Page.enable");
  await send("Runtime.enable");
  await send("Emulation.setDeviceMetricsOverride", {
    width: 1440,
    height: 900,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await send("Emulation.setEmulatedMedia", {
    features: [{ name: "prefers-reduced-motion", value: "no-preference" }],
  });
  await send("Page.navigate", { url: "http://localhost:4173/index.html" });
  await wait(700);

  for (const progress of [0, 0.25, 0.5, 0.75, 1]) {
    const label = String(Math.round(progress * 100)).padStart(3, "0");
    await capture(1440, 900, progress, "hero-t" + label + "-1440.png");
  }
  await capture(390, 844, 0, "hero-t000-390.png");
  await capture(390, 844, 1, "hero-t100-390.png");
  await capture(1068, 577, 1, "hero-t100-1068-short.png");
  for (const viewport of [
    [320, 700],
    [360, 780],
    [768, 900],
    [1024, 800],
    [1920, 1080],
  ]) {
    await capture(viewport[0], viewport[1], 1, "hero-t100-" + viewport[0] + ".png");
  }

  await send("Runtime.evaluate", {
    expression: "document.querySelector('.motion-replay').click()",
  });
  await wait(180);
  const replayState = await send("Runtime.evaluate", {
    expression: "({scrollY: window.scrollY, label: document.querySelector('.motion-replay').textContent, cover: getComputedStyle(document.querySelector('.front-cover')).transform})",
    returnByValue: true,
  });
  if (replayState.result.value.scrollY > 1 || replayState.result.value.label !== "Repetir apertura") {
    throw new Error("El control para repetir no devolvió el hero al estado inicial.");
  }

  await send("Emulation.setDeviceMetricsOverride", {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
  });
  await send("Emulation.setEmulatedMedia", {
    features: [{ name: "prefers-reduced-motion", value: "reduce" }],
  });
  await send("Page.reload");
  await wait(500);
  await send("Runtime.evaluate", { expression: "window.scrollTo(0, 0)" });
  await wait(120);
  await captureCurrent("hero-reduced-motion-390.png");
  const reducedState = await send("Runtime.evaluate", {
    expression: "({reduced: document.documentElement.classList.contains('motion-reduced'), label: document.querySelector('.motion-replay').textContent})",
    returnByValue: true,
  });
  if (!reducedState.result.value.reduced || reducedState.result.value.label !== "Activar animación") {
    throw new Error("La alternativa de movimiento reducido no expuso el control de activación.");
  }
  await send("Runtime.evaluate", {
    expression: "document.querySelector('.motion-replay').click()",
  });
  await wait(180);
  const optInState = await send("Runtime.evaluate", {
    expression: "({scrollY: window.scrollY, reduced: document.documentElement.classList.contains('motion-reduced'), label: document.querySelector('.motion-replay').textContent})",
    returnByValue: true,
  });
  if (optInState.result.value.scrollY > 1 || optInState.result.value.reduced || optInState.result.value.label !== "Repetir apertura") {
    throw new Error("La activación manual no habilitó la animación controlada por scroll.");
  }
  await captureCurrent("hero-reduced-opt-in-390.png");
  console.log("Capturas guardadas en " + outputDir);
} finally {
  socket.close();
  await new Promise((resolveExit) => {
    if (processHandle.exitCode !== null) {
      resolveExit();
      return;
    }
    processHandle.once("exit", resolveExit);
    processHandle.kill();
    setTimeout(resolveExit, 1000);
  });
  await wait(150);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      await rm(profileDir, { recursive: true, force: true });
      break;
    } catch (error) {
      if (attempt === 3) throw error;
      await wait(150);
    }
  }
}
