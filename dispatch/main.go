package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"strconv"
	"time"
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.17.0"
	"go.opentelemetry.io/otel/trace"

	"github.com/streadway/amqp"
)

const (
	Service = "dispatch"
)

var (
	amqpUri          string
	rabbitChan       *amqp.Channel
	rabbitCloseError chan *amqp.Error
	rabbitReady      chan bool
	errorPercent     int

	dataCenters = []string{
		"asia-northeast2",
		"asia-south1",
		"europe-west3",
		"us-east1",
		"us-west1",
	}
)

func initTracer() *sdktrace.TracerProvider {
	ctx := context.Background()
	
	exporter, err := otlptracegrpc.New(ctx)
	if err != nil {
		log.Fatalf("failed to create exporter: %v", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exporter),
		sdktrace.WithResource(resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String("dispatch"),
		)),
	)
	
    otel.SetTracerProvider(tp)
    
	otel.SetTextMapPropagator(propagation.TraceContext{})
	
    return tp
}

type AMQPHeaderCarrier map[string]interface{}

func (h AMQPHeaderCarrier) Get(key string) string {
	if v, ok := h[key]; ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

func (h AMQPHeaderCarrier) Set(key string, value string) {
	h[key] = value
}

func (h AMQPHeaderCarrier) Keys() []string {
	keys := make([]string, 0, len(h))
	for k := range h {
		keys = append(keys, k)
	}
	return keys
}

func connectToRabbitMQ(uri string) *amqp.Connection {
	for {
		conn, err := amqp.Dial(uri)
		if err == nil {
			return conn
		}

		log.Println(err)
		log.Printf("Reconnecting to %s\n", uri)
		time.Sleep(1 * time.Second)
	}
}

func rabbitConnector(uri string) {
	var rabbitErr *amqp.Error

	for {
		rabbitErr = <-rabbitCloseError
		if rabbitErr == nil {
			return
		}

		log.Printf("Connecting to %s\n", amqpUri)
		rabbitConn := connectToRabbitMQ(uri)
		rabbitConn.NotifyClose(rabbitCloseError)

		var err error

		// create mappings here
		rabbitChan, err = rabbitConn.Channel()
		failOnError(err, "Failed to create channel")

		// create exchange
		err = rabbitChan.ExchangeDeclare("robot-shop", "direct", true, false, false, false, nil)
		failOnError(err, "Failed to create exchange")

		// create queue
		queue, err := rabbitChan.QueueDeclare("orders", true, false, false, false, nil)
		failOnError(err, "Failed to create queue")

		// bind queue to exchange
		err = rabbitChan.QueueBind(queue.Name, "orders", "robot-shop", false, nil)
		failOnError(err, "Failed to bind queue")

		// signal ready
		rabbitReady <- true
	}
}

func failOnError(err error, msg string) {
	if err != nil {
		log.Fatalf("%s : %s", msg, err)
	}
}

func getOrderId(order []byte) string {
	id := "unknown"
	var f interface{}
	err := json.Unmarshal(order, &f)
	if err == nil {
		m := f.(map[string]interface{})
		id = m["orderid"].(string)
	}

	return id
}

func createSpan(headers map[string]interface{}, order string) {
	carrier := AMQPHeaderCarrier(headers)
	ctx := otel.GetTextMapPropagator().Extract(context.Background(), carrier)

	tracer := otel.Tracer("dispatch-service")
	
    log.Printf("order %s\n", order)

	ctx, span := tracer.Start(ctx, "getOrder", trace.WithSpanKind(trace.SpanKindConsumer))
	defer span.End()

	fakeDataCenter := dataCenters[rand.Intn(len(dataCenters))]
	span.SetAttributes(
        attribute.String("datacenter", fakeDataCenter),
        attribute.String("messaging.system", "rabbitmq"),
        attribute.String("messaging.destination", "robot-shop"),
        attribute.String("messaging.destination_kind", "queue"),
        attribute.String("messaging.operation", "process"),
        attribute.String("orderid", order),
    )

	time.Sleep(time.Duration(42+rand.Int63n(42)) * time.Millisecond)
	
	if rand.Intn(100) < errorPercent {
        // Record Error
		span.RecordError(fmt.Errorf("Failed to dispatch to SOP"))
		span.SetStatus(codes.Error, "Failed to dispatch to SOP")
		log.Println("Span tagged with error")
	}

	processSale(ctx, tracer)
}

func processSale(ctx context.Context, tracer trace.Tracer) {
	_, span := tracer.Start(ctx, "processSale")
	defer span.End()
	
    span.AddEvent("Order sent for processing")
	
    time.Sleep(time.Duration(42+rand.Int63n(42)) * time.Millisecond)
}

func main() {
	rand.Seed(time.Now().Unix())

	tp := initTracer()
	defer func() {
		if err := tp.Shutdown(context.Background()); err != nil {
			log.Printf("Error shutting down tracer provider: %v", err)
		}
	}()

	// Init amqpUri
	// get host from environment
	amqpHost, ok := os.LookupEnv("AMQP_HOST")
	if !ok {
		amqpHost = "rabbitmq"
	}
	amqpUri = fmt.Sprintf("amqp://guest:guest@%s:5672/", amqpHost)

	// get error threshold from environment
	errorPercent = 0
	epct, ok := os.LookupEnv("DISPATCH_ERROR_PERCENT")
	if ok {
		epcti, err := strconv.Atoi(epct)
		if err == nil {
			if epcti > 100 {
				epcti = 100
			}
			if epcti < 0 {
				epcti = 0
			}
			errorPercent = epcti
		}
	}
	log.Printf("Error Percent is %d\n", errorPercent)

	// MQ error channel
	rabbitCloseError = make(chan *amqp.Error)

	// MQ ready channel
	rabbitReady = make(chan bool)

	go rabbitConnector(amqpUri)

	rabbitCloseError <- amqp.ErrClosed

	go func() {
		for {
			// wait for rabbit to be ready
			ready := <-rabbitReady
			log.Printf("Rabbit MQ ready %v\n", ready)

			// subscribe to bound queue
			msgs, err := rabbitChan.Consume("orders", "", true, false, false, false, nil)
			failOnError(err, "Failed to consume")

			for d := range msgs {
				log.Printf("Order %s\n", d.Body)
				log.Printf("Headers %v\n", d.Headers)
				id := getOrderId(d.Body)
				
                // Call the updated createSpan
				go createSpan(d.Headers, id)
			}
		}
	}()

	log.Println("Waiting for messages")
	select {}
}
