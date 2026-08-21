FROM golang:1.20-alpine

WORKDIR /app
COPY go.mod ./
# No usamos go.sum porque lo inicializamos a mano y no hemos ejecutado go mod tidy,
# descargamos directamente la dependencia en el build
RUN go get github.com/graphql-go/graphql
COPY . .

RUN go build -o main .

EXPOSE 4001
CMD ["./main"]
