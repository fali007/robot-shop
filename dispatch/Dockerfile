FROM golang:1.25

WORKDIR /go/src/app

COPY * .

RUN go build -o dispatch .
CMD ["./dispatch"]
