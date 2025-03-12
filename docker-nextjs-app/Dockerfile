# stage 1 - install dependencies
FROM cgr.dev/chainguard/node as build-deps
WORKDIR /usr/src/app
# Switch to root temporarily to set up directories and permissions
USER root

# Create app directory and set permissions
RUN mkdir -p ./node_modules && \
    chown -R node:node ./
USER node
COPY --chown=node:node ./nextjs-app/package*.json ./

RUN npm install

# stage 2 - copy from stage 1 before next build
FROM cgr.dev/chainguard/node
WORKDIR /usr/src/app

COPY --from=build-deps --chown=node:node  /usr/src/app ./
COPY --chown=node:node ./nextjs-app .

USER root
RUN npm i typescript tsc -g
# Fix imageLoader url parameter not allowed 1 of 4 - convert imageLoader.ts to imageLoader.js before build (next.config.ts needs it)
RUN npx tsc --allowJs --outDir . --target esnext --skipLibCheck true --esModuleInterop true --module commonjs ./imageLoader.ts

RUN npm run build

# Build single next.config.ts as next.config.js
# Convert this to next.config.js for volume sharing on start of custom nextjs server
# Fix imageLoader url parameter not allowed
RUN npx tsc --allowJs --outDir . --target esnext --skipLibCheck true --esModuleInterop true --module commonjs ./next.config.ts
USER node
ENTRYPOINT ["/usr/bin/dumb-init", "--"]