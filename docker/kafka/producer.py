from confluent_kafka import Producer
import json
import time
import random

# Kafka Producer configuration
producer_config = {
    'bootstrap.servers': 'kafka-gameday.brewsentry.com:9095',  # Update with the correct broker and port
    'client.id': 'python-producer',
}

# Initialize the producer
producer = Producer(producer_config)

# Helper function to produce messages
def produce_message():
    # Generate a simple log-like message
    message = {
        'timestamp': time.time(),
        'log_level': random.choice(['INFO', 'DEBUG', 'ERROR']),
        'message': 'This is a test message from the Kafka producer!'
    }
    # Convert message to JSON and send it to Kafka
    producer.produce('test', key=str(message['timestamp']), value=json.dumps(message))
    producer.flush()

# Produce messages in a loop
if __name__ == "__main__":
    try:
        while True:
            produce_message()
            print("Message sent successfully!")
            time.sleep(1)  # Produce one message every second
    except KeyboardInterrupt:
        print("Producer stopped.")
