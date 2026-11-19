// 最小 preload，后续可以在这里暴露 electron-mpv-video 的 API
const { contextBridge } = require("electron");
contextBridge.exposeInMainWorld("appInfo", {
  platform: process.platform,
  versions: process.versions
});
