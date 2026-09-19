FROM golang:1.23-alpine AS builder
WORKDIR /app

# Copiar todo el código primero
COPY . .

# Actualizar todas las dependencias transitivas a su última versión compatible
# para asegurar que no existan CVEs con fix disponible
RUN go get -u ./... && go mod tidy

# Compilar el binario estáticamente
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o main .

FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/main .
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
EXPOSE 4001
CMD ["./main"]
