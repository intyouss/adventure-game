FROM alpine:3.21
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY adventure-server .
COPY config/ config/
COPY migrations/ migrations/
CMD ["./adventure-server"]
