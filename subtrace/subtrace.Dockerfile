FROM alpine:edge

RUN apk add --no-cache curl net-tools
RUN curl -fsSL https://subtrace.dev/install.sh | sh

CMD ["subtrace", "run", "--", "node", "./app.js"]