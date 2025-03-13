const http = require("http");
const next = require("next");
const path = require("path");
const fs = require("fs");
const chokidar = require("chokidar");
const { parse } = require("url");
const { exec } = require("child_process");

let timer = null;
let server = null;
let app = null;
let isRestarting = false;
let retryCount = 0;
const MAX_RETRIES = 3;

const {
  NODE_ENV = "development",
  PORT = 3000,
  VLM_DIR = "./",
  BLGREEN_SYMLINK = "current",
} = process.env;

const fileLocation = path.join(__dirname, VLM_DIR, "/states/uploaded");

const dirSymlink = path.join(__dirname, VLM_DIR, BLGREEN_SYMLINK);

console.log("next-server paths: ", { fileLocation, dirSymlink, PORT });

const forceReleasePort = async () => {
  return new Promise((resolve) => {
    console.log(`Attempting to forcibly release port ${PORT}...`);

    exec(`lsof -i :${PORT} -t | xargs kill -9 2>/dev/null || true`, (error) => {
      if (error) {
        console.log(`Could not forcibly release port: ${error.message}`);
      } else {
        console.log(`Port ${PORT} should be free now`);
      }
      setTimeout(resolve, 2000);
    });
  });
};

const stopServer = async () => {
  if (server) {
    console.log("Stopping Next.js server...");
    return new Promise((resolve) => {
      let closed = false;

      const closeTimeout = setTimeout(() => {
        if (!closed) {
          console.log(
            "Server close operation timed out, considering server stopped"
          );
          server = null;
          app = null;
          closed = true;
          resolve();
        }
      }, 3000);

      server.close(() => {
        clearTimeout(closeTimeout);
        if (!closed) {
          console.log("Next.js server stopped successfully");
          server = null;
          app = null;
          closed = true;
          resolve();
        }
      });
    });
  }
  return Promise.resolve();
};

const errorHandler = (resolve, reject) => async (error) => {
  console.error("nextjs errorHandler:", error);

  if (error.code === "EADDRINUSE") {
    console.error(`Port ${PORT} is already in use.`);
    retryCount++;
    if (retryCount <= MAX_RETRIES) {
      console.log(
        `Retrying startup (attempt ${retryCount + 1} of ${MAX_RETRIES + 1})...`
      );

      server = null;

      setTimeout(async () => {
        try {
          const newServer = await createServer();
          resolve(newServer);
        } catch (err) {
          reject(err);
        }
      }, 5000);
    } else {
      console.error(`Failed to start server after ${MAX_RETRIES + 1} attempts`);
      reject(
        new Error(`Failed to start server after ${MAX_RETRIES + 1} attempts`)
      );
    }
  } else {
    reject(error);
  }
};

const createServer = async () => {
  try {
    if (retryCount > 0) {
      await forceReleasePort();
      await new Promise((resolve) => setTimeout(resolve, 2000));
      console.log(
        `Creating Next.js app (attempt ${retryCount + 1} of ${
          MAX_RETRIES + 1
        })...`
      );
    } else {
      console.log("Starting Next.js app...");
    }

    app = next({
      dev: NODE_ENV !== "production",
      dir: dirSymlink,
      conf: { distDir: ".next" },
    });
    await app.prepare();
   
    return new Promise((resolve, reject) => {
      console.log("Creating HTTP server...");

      const handle = app.getRequestHandler();
      server = http.createServer((req, res) => {
        const parsedUrl = parse(req.url, true);
        handle(req, res, parsedUrl);
      });
      const errorHandlerCallback = errorHandler(resolve, reject);
      server.once("error", errorHandlerCallback);
      server.listen(PORT, (err) => {
        if (err) {
          console.error("Error in server. listen callback:", err);
          reject(err);
          return;
        }
        console.log(`> Ready on http://localhost:${PORT} Serving content from ${dirSymlink}`);
        server.removeListener("error", errorHandlerCallback);
        resolve(server);
      });
    });
  } catch (err) {
    console.error("Error preparing Next.js app:", err);
    throw err;
  }
};

const startServer = async () => {
  if (isRestarting) {
    console.log("Server restart already in progress, skipping...");
    return;
  }
  isRestarting = true;
  retryCount = 0;
  try {
    await stopServer();
    createServer()
      .then(() => {
        if (process.send) {
          process.send("ready");
        }
        isRestarting = false;
      })
      .catch((err) => {
        console.error("Error restarting server:", err);
        isRestarting = false;
      });
  } catch (err) {
    console.error("Failed to start server:", err);
    if (process.send) {
      process.send("error");
    }
    isRestarting = false;
  }
};

const keepContainerAlive = () => {
  if (timer) {
    clearInterval(timer);
  }
  timer = setInterval(() => {
    console.log("Container is running...");
  }, 60000); // Log every 60 seconds to prevent ECS timeout
};

const watchSymlink = () => {
  console.log(`Watching symlink: ${dirSymlink}`);

  const watcher = chokidar.watch(dirSymlink, {
    persistent: true,
    ignoreInitial: false,
    followSymlinks: false,
    awaitWriteFinish: {
      stabilityThreshold: 2000,
      pollInterval: 100,
    },
  });

  watcher
    .on("change", async () => {
      console.log("Symlink on change, restarting server...");
      startServer();
    })
    .on("add", async () => {
      console.log("Symlink on add, starting server...");
      startServer();
    })
    .on("unlink", async () => {
      console.log("Symlink on unlink, stopping server...");
      stopServer();
    })
    .on("error", (error) => {
      console.error("Symlink on error:", error);
    });

  if (fs.existsSync(dirSymlink)) {
    console.log("Symlink exists on startup, starting server...");
    startServer();
  }
};

const closeGracefully = async (signal) => {
  console.log(`Received signal to terminate: ${signal}`);
  if (timer) {
    clearInterval(timer);
  }
  await stopServer();
  process.exit(0);
};

process.once("SIGINT", closeGracefully);
process.once("SIGTERM", closeGracefully);

process.on("uncaughtException", (error) => {
  console.error("Uncaught exception:", error);
});

keepContainerAlive();
watchSymlink();
console.log("Server initialization complete");
