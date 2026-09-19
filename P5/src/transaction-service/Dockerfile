FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go get github.com/graphql-go/graphql
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

FROM alpine:3.20
WORKDIR /app
COPY --from=builder /app/main .
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
EXPOSE 4001
CMD ["./main"]

