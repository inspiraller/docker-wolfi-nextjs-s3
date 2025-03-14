const path = require('path');

// from Dockerfile environment variable
const {PORT, VLM_DIR, PM2_SERVER_NAME, BLGREEN_SYNCED } = process.env;

// import path, {dirname} from "path";
// import { fileURLToPath } from "url";
// const __filename = fileURLToPath(import.meta.url);
// const __dirname = dirname(__filename);

const ROOT_VLM_DIR=path.join(`${__dirname}/${VLM_DIR}`)

console.log('ecosystem.config.js PORT=',{ PM2_SERVER_NAME, BLGREEN_SYNCED, PORT, VLM_DIR, ROOT_VLM_DIR, __dirname });

module.exports = {
//export default {
  apps: [
    {
      name: PM2_SERVER_NAME,
      script: "./next-server.cjs",
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
        VLM_DIR,
        BLGREEN_SYNCED
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