package main

import (
	"github.com/hashicorp/vault/api"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"log"
	"net/http"
	"time"
)

var rpcs = prometheus.NewCounter(prometheus.CounterOpts{Name: "rpcs"})

func init() {
	http.Handle("/metrics", promhttp.Handler())
	prometheus.MustRegister(rpcs)
	go http.ListenAndServe(":8080", nil)
}

func main() {
	client, err := api.NewClient(api.DefaultConfig())
	if err != nil {
		log.Fatal(err)
	}

	for {
		_, err := client.Logical().Write("/auth/token/renew-self", nil)
		if err != nil {
			log.Fatal(err)
		}
		rpcs.Inc()
		time.Sleep(5 * time.Millisecond)
	}
}
