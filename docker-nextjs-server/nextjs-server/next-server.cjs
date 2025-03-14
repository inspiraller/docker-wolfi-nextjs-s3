const next = require("next");
const path = require("path");
const chokidar = require("chokidar");
const http = require("http");
const fs = require("fs");
const { parse } = require("url");

let timer = null;
let server = null;
let app = null;

const {
  NODE_ENV = "development",
  PORT = 3000,
  VLM_DIR = "./",
  BLGREEN_SYNCED,
} = process.env;

console.log("next-server paths: ", {
  NODE_ENV,
  PORT,
  VLM_DIR,
  BLGREEN_SYNCED,
});

const stopServer = (cb) => {
  server.close(() => {
    if (timer) {
      clearInterval(timer);
    }
    server = null;
    app = null;
    closed = true;
    cb?.();
  });
};

const startServer = async (dirBuild) => {
  try {
    console.log("app = next()");
    app = next({
      dev: NODE_ENV !== "production",
      dir: dirBuild,
      conf: { distDir: ".next" },
    });
    console.log("app.prepare()");
    await app.prepare();

    console.log("http.createServer");
    const handle = app.getRequestHandler();
    server = http.createServer((req, res) => {
      const parsedUrl = parse(req.url, true);
      handle(req, res, parsedUrl);
    });
    const errorHandlerCallback = () => {
      if (error.code === "EADDRINUSE") {
        console.error(`EADDRINUSE! Port ${PORT} is already in use.`);
      }
      throw error;
    };
    server.once("error", errorHandlerCallback);
    server.listen(PORT, (err) => {
      if (err) {
        console.error("Error in server. listen callback:", err);
        reject(err);
        return;
      }
      server.removeListener("error", errorHandlerCallback);
      console.log(
        `Ready on http://localhost:${PORT} Serving content from ${dirBuild}`
      );

      if (timer) {
        clearInterval(timer);
      }
      process.send("ready"); // for pm2
    });
  } catch (err) {
    console.error("Error preparing Next.js app:", err);
    throw err;
  }
};

const onExist = (to_build) => {
  const dirBuild = path.join(__dirname, VLM_DIR, to_build);
  startServer(dirBuild);
};

const watchBuild = () => {
  const triggerFilePath = path.join(
    __dirname,
    VLM_DIR,
    BLGREEN_SYNCED,
    "build"
  );

  // Check if the file exists before watching
  if (!fs.existsSync(path.dirname(triggerFilePath))) {
    console.error(
      `Directory for trigger file doesn't exist: ${path.dirname(
        triggerFilePath
      )}`
    );
    console.log("Creating directory structure...", path.dirname(triggerFilePath));
    fs.mkdirSync(path.dirname(triggerFilePath), { recursive: true });
  }

  console.log(`watchBuild - setup on trigger file: ${triggerFilePath}`);
  const watcher = chokidar.watch(triggerFilePath, {
    persistent: true,
    ignoreInitial: false, // Check if file exists on startup
    awaitWriteFinish: {
      stabilityThreshold: 2000,
      pollInterval: 100,
    },
    usePolling: true,
    interval: 1000,
  });

  const onAnything = () => {
    console.log(`Trigger file detected: ${triggerFilePath}`);
    try {
      if (!fs.existsSync(triggerFilePath)) {
        console.log('file doentexist yet', triggerFilePath);
        return;
      }
      const content = fs.readFileSync(triggerFilePath, "utf8").trim();
      console.log(`Trigger file content: ${content}`);

      if (content) {
        console.log("content=", content);
        watcher
          .close()
          .then(() => {
            console.log("File watcher closed");
            onExist(content);
          })
          .catch((err) => {
            console.error("Error closing watcher:", err);
            onExist(content);
          });
      }
    } catch (err) {
      console.log("trigger catch error:", err);
    }
  };
  watcher
    .on("change", async () => {
      console.log("watcher - on change");
      onAnything();
    })
    .on("add", async () => {
      console.log("watcher - on add");
      onAnything();
    })
    .on("error", (error) => {
      console.error("Symlink on error:", error);
    });

  return watcher;
};

const keepContainerAlive = () => {
  if (timer) {
    clearInterval(timer);
  }
  timer = setInterval(() => {
    console.log("Container is running...");
  }, 60000);
};

const closeGracefully = async (signal) => {
  console.log(`Received signal to terminate: ${signal}`);
  if (timer) {
    clearInterval(timer);
  }
  stopServer(() => {
    process.exit(0);
  });
};

process.once("SIGINT", closeGracefully);
process.once("SIGTERM", closeGracefully);

process.on("uncaughtException", (error) => {
  console.error(
    "nextjs Uncaught exception. capture error but keep running:",
    error
  );
});

keepContainerAlive();
watchBuild();
console.log("Server initialization complete");
