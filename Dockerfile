# Stage 1: Build
FROM golang:1.25-alpine AS builder

WORKDIR /app

# Install git for fetching dependencies
RUN apk add --no-cache git

# Copy dependency files first for layer caching
COPY Server/MuchToDo/go.mod Server/MuchToDo/go.sum ./

RUN go mod download

# Copy application source
COPY Server/MuchToDo/ .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server ./cmd/api

# Stage 2: Runtime
FROM alpine:3.19

RUN apk add --no-cache ca-certificates curl

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy binary and entrypoint from builder
COPY --from=builder /app/server .
COPY entrypoint.sh .

RUN chmod +x entrypoint.sh && chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
