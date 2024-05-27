FROM golang:1.22-alpine

WORKDIR /app

COPY src/ .

RUN go mod download

RUN go build -o tic-tac-toe

EXPOSE 8080

ENV DOMAIN=aaa

CMD [ "./tic-tac-toe" ]
