FROM cgr.dev/chainguard/wolfi-base AS build-deps
RUN apk update && apk add --no-cache \
 nodejs-20 npm  && \
 rm -rf /var/cache/apk/*
ENV NODE_ENV="production"

WORKDIR /app
COPY nextjs-server/package.json nextjs-server/package-lock.json ./
RUN npm ci --omit=dev && npm prune --production

FROM cgr.dev/chainguard/wolfi-base
ARG USER_ID
ARG PORT

ENV NODE_ENV="production"
ENV PORT=$PORT

ENV VLM_DIR=
ENV BLGREEN_SYNCED=
ENV BLGREEN_BUILD1=
ENV BLGREEN_BUILD2=
ENV ROOT= 
ENV PM2_SERVER_NAME=


# inotify-tools for watching /states/uploaded to trigger rebuild 
# Note: This is problematic when used in Dockerfile. Currently using a poll, but in ec2 instance can use inotify-tools
RUN apk update && apk add --no-cache \
 nodejs-20 npm shadow curl dumb-init && \
 rm -rf /var/cache/apk/*
RUN groupadd -g $USER_ID node && useradd -m -u $USER_ID -g node -s /bin/sh node

WORKDIR /app 

RUN node --version

RUN mkdir -p ./scripts && \
   chown -R node:node ./scripts && \
   chmod -R 700 ./scripts
  
# for pm2 clustering. fixes bug 
# > Error while calling "getconf PAGESIZE" Error: Command failed: getconf PAGESIZE docker-wolfi-nextjs-s3  | /bin/sh: getconf: not found
RUN mkdir -p /usr/local/bin && \
   echo -e '#!/bin/sh\necho 4096' > /usr/local/bin/getconf && \
   chmod +x /usr/local/bin/getconf

COPY --from=build-deps --chown=node:node  /app /app
COPY --chown=node:node ./nextjs-server /app
COPY --chown=node:node ./scripts ./scripts

EXPOSE $PORT

HEALTHCHECK --interval=30s --timeout=10s --retries=2 \
  CMD ./scripts/healthcheck.sh

USER node:node
ENTRYPOINT ["./scripts/entrypoint.sh"]
# ENTRYPOINT ["/usr/bin/dumb-init", "--"]
# CMD ["node","nextjs-server.js"]  
# CMD ["sh", "-c", "node ./node_modules/pm2/lib/binaries/CLI.js start ecosystem.config.js"]
