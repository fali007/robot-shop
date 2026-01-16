FROM node:20-bookworm

ENV INSTANA_AUTO_PROFILE true

EXPOSE 8080

WORKDIR /opt/server

COPY package.json /opt/server/

RUN npm install

COPY tracing.js /opt/server/
COPY server.js /opt/server/

CMD ["node", "server.js"]

