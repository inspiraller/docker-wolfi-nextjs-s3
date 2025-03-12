const http = require("http");
const next = require("next");
const path = require("path");
const fs = require("fs");
const chokidar = require("chokidar");

let timer = null;
const {
  NODE_ENV = "development",
  PORT,
  CONTAINER_SHARED_PATH = "./",
} = process.env;

const fileLocation = path.join(__dirname, CONTAINER_SHARED_PATH, "states/uploaded");

let server = null;
let app = null;

const startServer = async () => {
  if (server) return; // Prevent multiple instances
  console.log(`Starting Next.js server...`);
  app = next({
    dev: NODE_ENV !== "production",
    dir: CONTAINER_SHARED_PATH,
    conf: { distDir: CONTAINER_SHARED_PATH }, // expect: ./next.config.js here
  });

  const handle = app.getRequestHandler();

  try {
    await app.prepare();

    server = http.createServer((req, res) => handle(req, res));

    server.listen(PORT, () => {
      console.log(`> Ready on http://localhost:${PORT}`);
      console.log("Serving content from", CONTAINER_SHARED_PATH);
      process.send('ready'); // for pm2
      console.log('sent ready!!!!!')
    });
  } catch (err) {
    console.error("Error starting server:", err);
  }
};

const stopServer = () => {
  if (server) {
    console.log("Stopping Next.js server...");
    server.close(() => {
      console.log("Next.js server stopped.");
      server = null;
    });
  }
};

const keepContainerAlive = () => {
  timer = setInterval(() => {
    console.log("Container is running but server is idle...");
  }, 60000); // Log every 60 seconds to prevent ECS timeout
};

const watchFile = () => {
  console.log(`Watching for changes: ${fileLocation}. watch on dirname:`, path.dirname(fileLocation));
  const watcher = chokidar.watch(fileLocation, { persistent: true, ignoreInitial: true });
  watcher
    .on("add", () => {
      console.log("File detected. Starting server...");
      startServer();
    })
    .on("unlink", () => {
      console.log("File removed. Stopping server...");
      stopServer();
    })
    .on("change", () => {
      console.log("File removed. Stopping server...");
      setTimeout(startServer, 1000); // 1 second delay before restarting
    })
    .on("error", (error) => {
      console.error("Watcher error:", error);
    });

  let fileExists = fs.existsSync(fileLocation);

  fs.watch(path.dirname(fileLocation), (eventType, filename) => {
    if (filename !== "uploaded") {console.log('file uploaded not found:', {eventType, filename}); return};
    console.log(`Detected change: ${eventType} ${filename}`);
    const fileNowExists = fs.existsSync(fileLocation);

    if (fileNowExists && !fileExists) {
      console.log("Detected 'uploaded' file. Starting server...");
      startServer();
    } else if (!fileNowExists && fileExists) {
      console.log("Detected 'uploaded' file removal. Stopping server...");
      stopServer();
    }

    fileExists = fileNowExists;
  });

  if (fileExists) {
    startServer();
  }
  keepContainerAlive();
};

const closeGracefully = async (signal) => {
  if (timer) {
    clearInterval(timer);
  }
  console.log(`*^!@4=> Received signal to terminate: ${signal}`);
  await server.close();
  process.kill(process.pid, signal);
};

process.once("SIGINT", closeGracefully);
process.once("SIGTERM", closeGracefully);

watchFile();
