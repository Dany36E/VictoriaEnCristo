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
const runtimeErrors = [];

socket.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (message.method === "Runtime.exceptionThrown") {
    runtimeErrors.push(message.params.exceptionDetails.text);
  }
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

async function benchmarkScroll(from, to, duration) {
  const result = await send("Runtime.evaluate", {
    expression: "new Promise(function (resolve) {" +
      "var hero = document.querySelector('.book-hero');" +
      "var distance = hero.offsetHeight - window.innerHeight;" +
      "var started = performance.now();" +
      "var previous = null;" +
      "var samples = [];" +
      "function step(now) {" +
        "if (previous !== null) samples.push(now - previous);" +
        "previous = now;" +
        "var elapsed = Math.min((now - started) / " + duration + ", 1);" +
        "var eased = elapsed * elapsed * (3 - 2 * elapsed);" +
        "window.scrollTo(0, distance * (" + from + " + (" + (to - from) + ") * eased));" +
        "if (elapsed < 1) { requestAnimationFrame(step); return; }" +
        "var stable = samples.slice(3).sort(function (a, b) { return a - b; });" +
        "var total = stable.reduce(function (sum, value) { return sum + value; }, 0);" +
        "resolve({frames: stable.length, averageMs: total / stable.length, p95Ms: stable[Math.floor(stable.length * 0.95)], maxMs: stable[stable.length - 1]});" +
      "}" +
      "requestAnimationFrame(step);" +
    "})",
    awaitPromise: true,
    returnByValue: true,
  });
  await wait(120);
  return result.result.value;
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

  const forwardBenchmark = await benchmarkScroll(0, 1, 1600);
  const forwardState = await send("Runtime.evaluate", {
    expression: "parseFloat(document.querySelector('.hero-progress span').style.width)",
    returnByValue: true,
  });
  const reverseBenchmark = await benchmarkScroll(1, 0, 1600);
  const reverseState = await send("Runtime.evaluate", {
    expression: "parseFloat(document.querySelector('.hero-progress span').style.width)",
    returnByValue: true,
  });
  if (forwardState.result.value < 99.5 || reverseState.result.value > 0.5) {
    throw new Error("La animación no siguió el scroll completo en ambas direcciones.");
  }
  console.log("Fluidez de scroll: " + JSON.stringify({ forward: forwardBenchmark, reverse: reverseBenchmark }));
  if (forwardBenchmark.p95Ms > 25 || reverseBenchmark.p95Ms > 25) {
    throw new Error("La cadencia del scroll superó 25 ms en el percentil 95.");
  }

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
  await send("Runtime.evaluate", {
    expression: "window.scrollTo(0, (document.querySelector('.book-hero').offsetHeight - window.innerHeight) * 0.5)",
  });
  await wait(180);
  await captureCurrent("hero-reduced-motion-active-390.png");
  const reducedState = await send("Runtime.evaluate", {
    expression: "({reducedClass: document.documentElement.classList.contains('motion-reduced'), buttonExists: Boolean(document.querySelector('.motion-replay')), progress: parseFloat(document.querySelector('.hero-progress span').style.width)})",
    returnByValue: true,
  });
  if (reducedState.result.value.reducedClass || reducedState.result.value.buttonExists || Math.abs(reducedState.result.value.progress - 50) > 1) {
    throw new Error("La animación no quedó activa por defecto sin controles adicionales.");
  }

  await send("Emulation.setEmulatedMedia", {
    features: [{ name: "prefers-reduced-motion", value: "no-preference" }],
  });
  await send("Emulation.setDeviceMetricsOverride", {
    width: 1440,
    height: 1100,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await send("Page.navigate", { url: "http://localhost:4173/ayuda.html#leer-biblia" });
  await wait(700);
  const helpValidation = await send("Runtime.evaluate", {
    expression: "(function () {" +
      "var search = document.getElementById('help-search');" +
      "function visibleCount(query) {" +
        "search.value = query;" +
        "search.dispatchEvent(new Event('input', {bubbles: true}));" +
        "return document.querySelectorAll('.guide-card:not([hidden])').length;" +
      "}" +
      "var result = {" +
        "deepLinkOpen: document.getElementById('leer-biblia').open," +
        "partial: visibleCount('interlin')," +
        "withoutAccent: visibleCount('oracion')," +
        "noResult: visibleCount('resultado imposible 987654321')" +
      "};" +
      "result.emptyVisible = document.getElementById('help-empty').classList.contains('is-visible');" +
      "search.value = '';" +
      "search.dispatchEvent(new Event('input', {bubbles: true}));" +
      "return result;" +
    "})()",
    returnByValue: true,
  });
  const helpState = helpValidation.result.value;
  if (!helpState.deepLinkOpen || helpState.partial < 1 || helpState.withoutAccent < 1 || helpState.noResult !== 0 || !helpState.emptyVisible) {
    throw new Error("El buscador o los enlaces profundos de ayuda no superaron la prueba: " + JSON.stringify(helpState));
  }
  await captureCurrent("ayuda-biblia-1440.png");
  await send("Emulation.setDeviceMetricsOverride", {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
  });
  await send("Page.reload");
  await wait(600);
  await captureCurrent("ayuda-biblia-390.png");

  await send("Emulation.setDeviceMetricsOverride", {
    width: 1440,
    height: 1000,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await send("Page.navigate", { url: "http://localhost:4173/index.html" });
  await wait(600);
  await send("Runtime.evaluate", {
    expression: "document.querySelector('.app-proof').scrollIntoView({block: 'start'})",
  });
  await wait(300);
  await captureCurrent("app-proof-1440.png");
  await send("Emulation.setDeviceMetricsOverride", {
    width: 390,
    height: 844,
    deviceScaleFactor: 1,
    mobile: true,
  });
  await send("Page.reload");
  await wait(600);
  await send("Runtime.evaluate", {
    expression: "document.querySelector('.app-proof').scrollIntoView({block: 'start'})",
  });
  await wait(300);
  await captureCurrent("app-proof-390.png");

  if (runtimeErrors.length) {
    throw new Error("Se detectaron errores de JavaScript: " + runtimeErrors.join(" | "));
  }
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
