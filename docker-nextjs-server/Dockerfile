FROM cgr.dev/chainguard/wolfi-base AS build-deps
RUN apk update && apk add --no-cache \
 nodejs-20 npm  && \
 rm -rf /var/cache/apk/*
ENV NODE_ENV="production"

WORKDIR /app
COPY nextjs-server/package.json nextjs-server/package-lock.json ./
RUN npm ci --omit=dev && npm prune --production

FROM cgr.dev/chainguard/wolfi-base
ARG CONTAINER_SHARED_PATH
ARG PORT
ARG USER_ID

ENV PORT=$PORT
ENV CONTAINER_SHARED_PATH=$CONTAINER_SHARED_PATH
ENV NODE_ENV="production"

# coreutils and glibc-conf for pm2 for clustering...
RUN apk update && apk add --no-cache \
 nodejs-20 npm shadow curl dumb-init && \
 rm -rf /var/cache/apk/*
RUN groupadd -g $USER_ID node && useradd -m -u $USER_ID -g node -s /bin/sh node



WORKDIR /app


RUN node --version

# Why permissions 700?
# ec2 is the root and therefore the owner so it has greater privilege, ie can write (7) to: /shared/.next
# docker/ecs would not typically be the root, but since its a bind mount, it takes on same ids as the host, but may have its own 
# naming conventions for those ids. the node user might be a different id.
# So as long as we specify the USER_ID we can have the same root permissions as the ec2

RUN \
 mkdir -p ./${CONTAINER_SHARED_PATH}/.next && \
   chmod -R 700 ./${CONTAINER_SHARED_PATH} && \
   chmod -R 700 ./${CONTAINER_SHARED_PATH}/.next && \
 mkdir -p ./scripts && \
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
