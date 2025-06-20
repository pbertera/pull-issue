FROM docker.io/library/golang:1.24
WORKDIR /src
COPY <<EOF ./main.go
package main

import (
    "fmt"
    "os"
    "time"
)

  func main() {
  fmt.Println("VERSION: ", os.Getenv("VERSION"))
  for {
    time.Sleep(1 * time.Second)
  }
}
EOF
RUN go build -o /bin/main ./main.go

FROM scratch
ENV VERSION 2
COPY --from=0 /bin/main /bin/main
CMD ["/bin/main"]
