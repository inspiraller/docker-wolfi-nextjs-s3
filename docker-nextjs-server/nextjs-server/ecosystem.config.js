

// from Dockerfile environment variable
const PORT = process.env.PORT;
const CONTAINER_SHARED_PATH = process.env.CONTAINER_SHARED_PATH;

console.log('ecosystem.config.js PORT=',{ PORT, CONTAINER_SHARED_PATH});
module.exports = {
  apps: [
    {
      name: "next-server",
      script: "./next-server.js",
      instances: "1",
      exec_mode: "fork",
      max_memory_restart: "300M",
      out_file: `./${CONTAINER_SHARED_PATH}/out.log`,
      error_file: `./${CONTAINER_SHARED_PATH}/error.log`,
      merge_logs: true,
      log_date_format: "DD-MM HH:mm:ss Z",
      log_type: "json",
      env_production: {
        NODE_ENV: "production",
        PORT,
      },
      wait_ready: true,
      listen_timeout: 20000,
      kill_timeout: 5000
    },
  ],
};