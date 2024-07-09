require 'bunny'

module RabbitmqQueue
  def self.new_connection
    Bunny.new(
      host: '3.106.240.194',
      port: 5672,
      user: 'lukodds',
      password: '25494143'
    )
  end

  def self.publish_message(data)
    puts "----------------------------------- publishing -----------------------------------"
    puts "----------------------------------- #{data} -----------------------------------"
    connection = RabbitmqQueue.new_connection

    begin
      connection.start
      channel = connection.create_channel
      queue = channel.queue('my_queue', durable: true)

      # Convert data to JSON
      json_message = data.to_json

      # Publish JSON message
      channel.default_exchange.publish(
        json_message,
        routing_key: queue.name,
        content_type: 'application/json'
      )

      puts "Published JSON message: #{json_message}"
      true
    rescue Bunny::TCPConnectionFailed => e
      Rails.logger.error "Connection to RabbitMQ failed: #{e.message}"
      false
    rescue JSON::GeneratorError => e
      Rails.logger.error "Failed to generate JSON: #{e.message}"
      false
    ensure
      connection.close if connection&.open?
    end
  end


  def self.consume_message(max_messages = 1)
    puts "--------------------------------- Consuming message ---------------------------------"
    connection = RabbitmqQueue.new_connection
    message_count = 0
  
    begin
      connection.start
      channel = connection.create_channel
      queue = channel.queue('my_queue', durable: true)
      
      puts "Waiting for up to #{max_messages} messages in #{queue.name}. To exit press CTRL+C"
      
      consumer = queue.subscribe(block: false) do |delivery_info, properties, body|
        puts "Received #{body}"
        # Process the message here
        
        message_count += 1
        if message_count >= max_messages
          channel.basic_cancel(consumer.consumer_tag)
        end
      end
  
      # Keep the main thread alive until all messages are processed
      loop do
        break if message_count >= max_messages
        sleep 1
      end
  
    rescue Interrupt => _
      puts "Interrupt received, shutting down..."
    ensure
      consumer.cancel if consumer
      channel.close if channel
      connection.close if connection.open?
      puts "Connection closed."
    end
  end

end

