const { app, BrowserWindow } = require("electron");
const path = require("path");

// 让打包后的应用能找到 resources/libmpv/libmpv-2.dll
const libmpvDir = path.join(process.resourcesPath, "libmpv");
if (process.platform === "win32") {
  process.env.PATH = `${libmpvDir};${process.env.PATH}`;
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 720,
    backgroundColor: "#000000",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      nodeIntegration: false,
      contextIsolation: true
    }
  });
  win.loadFile(path.join(__dirname, "index.html"));
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
