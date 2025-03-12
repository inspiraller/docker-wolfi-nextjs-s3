

// from Dockerfile environment variable
const {PORT, VLM_DIR, BLGREEN_SYMLINK, PM2_SERVER_NAME } = process.env;
const path = require('path');


const ROOT_VLM_DIR=path.join(`${__dirname}/${VLM_DIR}`)

console.log('ecosystem.config.js PORT=',{ PM2_SERVER_NAME, PORT, VLM_DIR, BLGREEN_SYMLINK, ROOT_VLM_DIR, __dirname });

module.exports = {
  apps: [
    {
      name: PM2_SERVER_NAME,
      script: "./next-server.js",
      instances: "1",
      exec_mode: "fork",
      max_memory_restart: "300M",
      out_file: `./${VLM_DIR}/logs/out.log`,
      error_file: `./${VLM_DIR}/logs/error.log`,
      merge_logs: true,
      log_date_format: "DD-MM HH:mm:ss Z",
      log_type: "json",
      env_production: {
        NODE_ENV: "production",
        PORT,
        BLGREEN_SYMLINK,
        VLM_DIR
      },
      wait_ready: true,
      //listen_timeout: 0, // No timeout, wait indefinitely

      listen_timeout: 30000, // 30 seconds timeout
      kill_timeout: 10000,   // Give it 10 seconds to shut down gracefully
      restart_delay: 5000,   // Wait 5 seconds between restarts
      max_restarts: 10,      // Maximum number of automatic restarts
      autorestart: true,     // Restart on crash
      force: true           // Force kill if needed
    },
  ],
};