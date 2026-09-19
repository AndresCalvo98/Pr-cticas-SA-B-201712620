FROM golang:1.24-alpine AS builder
WORKDIR /app

# Copiar todo el código fuente
COPY . .

# Actualizar todas las dependencias a sus últimas versiones compatibles
RUN go get -u ./... && go mod tidy

# Compilar con -trimpath para eliminar info de rutas locales del binario
# y -ldflags para reducir el tamaño y metadata del binario
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o main .

FROM alpine:3.21
WORKDIR /app
COPY --from=builder /app/main .
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
EXPOSE 4001
CMD ["./main"]
