import type { NextConfig } from "next";
const nextConfig: NextConfig = {
  images: {
    domains: [
      "image.tmdb.org",
    ],
    // Fix imageLoader url parameter not allowed 1 of 4 - convert imageLoader.ts to imageLoader.js before build (next.config.ts needs it)
    loader: "custom",
    loaderFile: "./imageLoader.js", // check this evaluates. 
    remotePatterns: [
      {
        hostname: "image.tmdb.org",
        pathname: "/**",
        port: "80",
      },
    ],
  },
};

export default nextConfig;
