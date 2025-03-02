# Housing Data Streaming with Kafka

## Introduction

This project demonstrates a Kafka-based data streaming pipeline for housing data. It consists of:

1. A **Kafka Broker** running in Docker (using KRaft mode, no Zookeeper required).
2. A **Kafka Consumer** (`housing-consumer`) implemented in Python to consume messages from `housing_topic` and send them to `housing-api`.
3. A **Kafka Producer** (`housing-producer`) implemented in Python for testing the pipeline.

## Prerequisites

Ensure you have the following installed:

- Docker & Docker Compose
- Python 3.8+ (recommended to use `pyenv`)
- Poetry (for dependency management)

---

## Step 1: Set Up Kafka with Docker Compose

Create a `docker-compose.yml` file to run a Kafka broker.

```yaml
docker-compose.yml
version: '3.8'

services:
  broker:
    image: confluentinc/cp-kafka:latest
    container_name: broker
    hostname: broker
    ports:
      - 9092:9092
      - 29092:29092
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://broker:9092,PLAINTEXT_HOST://localhost:29092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@broker:29093
      KAFKA_LISTENERS: PLAINTEXT://broker:9092,CONTROLLER://broker:29093,PLAINTEXT_HOST://0.0.0.0:29092
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LOG_DIRS: /tmp/kraft-combined-logs
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qk
    healthcheck:
      test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "broker:9092"]
      interval: 10s
      timeout: 5s
      retries: 5
```

Run the Kafka broker:

```sh
docker-compose up -d
```

---

## Step 2: Implement the Kafka Consumer

### 1. Create a `housing-consumer` sub-project

```sh
mkdir housing-consumer && cd housing-consumer
pyenv local 3.9.0  # (Optional) Set Python version
poetry init  # Initialize Poetry project
poetry add confluent-kafka requests
```

### 2. Implement `consumer.py`

```python
from confluent_kafka import Consumer
import json
import requests

KAFKA_BROKER = "localhost:29092"
KAFKA_TOPIC = "housing_topic"
API_ENDPOINT = "http://housing-api:5000/process"

consumer_config = {
    'bootstrap.servers': KAFKA_BROKER,
    'group.id': 'housing_group',
    'auto.offset.reset': 'earliest'
}

consumer = Consumer(consumer_config)
consumer.subscribe([KAFKA_TOPIC])

while True:
    msg = consumer.poll(1.0)
    if msg is None:
        continue
    if msg.error():
        print(f"Consumer error: {msg.error()}")
        continue
    
    data = json.loads(msg.value().decode('utf-8'))
    print(f"Received: {data}")
    
    response = requests.post(API_ENDPOINT, json=data)
    print(f"API Response: {response.status_code}")

consumer.close()
```

### 3. Dockerize the Consumer

Create a `Dockerfile`:

```Dockerfile
FROM python:3.9
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["python", "consumer.py"]
```

Build and run:

```sh
docker build -t housing-consumer .
docker run --network host housing-consumer
```

---

## Step 3: Implement the Kafka Producer (for testing)

### 1. Create `producer.py`

```python
from confluent_kafka import Producer
import json
import time

KAFKA_BROKER = "localhost:29092"
KAFKA_TOPIC = "housing_topic"

def delivery_report(err, msg):
    if err:
        print(f"Message failed: {err}")
    else:
        print(f"Message delivered to {msg.topic()} [{msg.partition()}]")

producer = Producer({'bootstrap.servers': KAFKA_BROKER})

message = {
    "longitude": -122.23,
    "latitude": 37.88,
    "housing_median_age": 52,
    "total_rooms": 880,
    "total_bedrooms": 129,
    "population": 322,
    "households": 126,
    "median_income": 8.3252,
    "median_house_value": 358500,
    "ocean_proximity": "NEAR BAY"
}

producer.produce(KAFKA_TOPIC, json.dumps(message).encode('utf-8'), callback=delivery_report)
producer.flush()
```

Run the producer:

```sh
python producer.py
```

---

## Step 4: Testing the Setup

1. Start Kafka: `docker-compose up -d`
2. Run the consumer: `docker run --network host housing-consumer`
3. Send a test message with the producer: `python producer.py`
4. Check logs to verify messages are processed and sent to `housing-api`.

---

## Conclusion

This project demonstrates how to:

- Set up Kafka in Docker Compose
- Implement a Python consumer that reads messages from Kafka and forwards them to an API
- Implement a Python producer for testing
- Dockerize the consumer for easy deployment

Next steps:

- Improve error handling
- Implement retries in case of API failures
- Deploy the solution in Kubernetes

