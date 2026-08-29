FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --production

COPY router.js ./

EXPOSE 4001

ENV PORT=4001
ENV OLLAMA_HOST=http://ollama:11434
ENV LITELLM_HOST=http://litellm:4000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=20s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4001/health || exit 1

CMD ["node", "router.js"]
