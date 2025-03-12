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

const fileLocation = path.join(
  __dirname,
  VLM_DIR,
  "/states/uploaded"
);

const dirSymlink = path.join(
  __dirname,
  VLM_DIR,
  BLGREEN_SYMLINK
);

console.log("next-server paths: ", { fileLocation, dirSymlink, PORT });

// Function to forcibly free up the port if it's in use
const forceReleasePort = async () => {
  return new Promise((resolve) => {
    console.log(`Attempting to forcibly release port ${PORT}...`);
    
    // Find the process using the port and kill it (Linux/Unix only)
    exec(`lsof -i :${PORT} -t | xargs kill -9 2>/dev/null || true`, (error) => {
      if (error) {
        console.log(`Could not forcibly release port: ${error.message}`);
      } else {
        console.log(`Port ${PORT} should be free now`);
      }
      // Wait a moment for the OS to release the port
      setTimeout(resolve, 2000);
    });
  });
};

const stopServer = async () => {
  if (server) {
    console.log("Stopping Next.js server...");
    return new Promise((resolve) => {
      let closed = false;
      
      // Set a timeout in case server.close() hangs
      const closeTimeout = setTimeout(() => {
        if (!closed) {
          console.log("Server close operation timed out, considering server stopped");
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

// Create a new server instance with proper error handling
const createServer = async () => {
  try {
    // If retrying, force port release first
    if (retryCount > 0) {
      await forceReleasePort();
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
    
    console.log(`Creating Next.js app (attempt ${retryCount + 1} of ${MAX_RETRIES + 1})...`);
    
    // Create the Next.js app
    app = next({
      dev: NODE_ENV !== "production",
      dir: dirSymlink,
      conf: { distDir: ".next" },
    });

    // Prepare the app
    console.log("Preparing Next.js app...");
    await app.prepare();
    
    const handle = app.getRequestHandler();
    
    // Create a new server
    console.log("Creating HTTP server...");
    server = http.createServer((req, res) => {
      const parsedUrl = parse(req.url, true);
      handle(req, res, parsedUrl);
    });
    
    // Return a promise that resolves when the server starts or rejects on error
    return new Promise((resolve, reject) => {
      // Set up error handler
      const errorHandler = async (error) => {
        console.error("Server startup error:", error);
        
        // Remove the error listener to prevent multiple triggers
        server.removeListener('error', errorHandler);
        
        if (error.code === 'EADDRINUSE') {
          console.error(`Port ${PORT} is already in use.`);
          
          // Increment retry count and check if we've exceeded max retries
          retryCount++;
          if (retryCount <= MAX_RETRIES) {
            console.log(`Retrying startup (attempt ${retryCount + 1} of ${MAX_RETRIES + 1})...`);
            
            // Clean up current server
            server = null;
            
            // Wait a moment and retry
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
            reject(new Error(`Failed to start server after ${MAX_RETRIES + 1} attempts`));
          }
        } else {
          // For other errors, just reject
          reject(error);
        }
      };
      
      // Attach the error handler
      server.once('error', errorHandler);
      
      // Try to start the server
      console.log(`Attempting to listen on port ${PORT}...`);
      server.listen(PORT, (err) => {
        if (err) {
          // This shouldn't happen as errors should be caught by the error handler
          console.error("Error in server.listen callback:", err);
          reject(err);
          return;
        }
        
        // Server started successfully
        console.log(`> Ready on http://localhost:${PORT}`);
        console.log("Serving content from", dirSymlink);
        
        // Remove the error handler as it's no longer needed
        server.removeListener('error', errorHandler);
        
        // Resolve with the server instance
        resolve(server);
      });
    });
  } catch (err) {
    console.error("Error preparing Next.js app:", err);
    throw err;
  }
};

const startServer = async () => {
  // Prevent concurrent restart attempts
  if (isRestarting) {
    console.log("Server restart already in progress, skipping...");
    return;
  }
  
  isRestarting = true;
  retryCount = 0;
  
  try {
    // Stop the existing server if it's running
    await stopServer();
    
    // Create and start a new server
    await createServer();
    
    // Tell PM2 we're ready
    if (process.send) {
      process.send("ready");
    }
    
    // Reset restart flag
    isRestarting = false;
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

// Watch for changes to the symlink itself
const watchSymlink = () => {
  console.log(`Watching symlink: ${dirSymlink}`);
  
  const watcher = chokidar.watch(dirSymlink, {
    persistent: true,
    ignoreInitial: false,
    followSymlinks: false,
    awaitWriteFinish: {
      stabilityThreshold: 2000,
      pollInterval: 100
    }
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
    
  // Also start the server initially if the symlink exists
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

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
  // Don't exit the process, just log the error
});

// Start the application
keepContainerAlive();
watchSymlink();
console.log("Server initialization complete");