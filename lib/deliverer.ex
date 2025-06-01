defmodule Deliverer do
  use GenServer
  @exchange_name "orders"

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: elem(options, 0))
  end

  def send_message(state, routing_key) do
    Process.sleep(2000)
    order_id = "#{state.id}|#{routing_key}|#{state.deliver_name}"
    IO.puts(" [x] Delivering order #{order_id}")

    AMQP.Basic.publish(
      state.channel,
      @exchange_name,
      routing_key,
      "We sent your order:" <> order_id
    )

    %{state | id: (state.id || 0) + 1}
  end

  @impl true
  def init(options) do
    {deliver_name, items_to_sell} = options
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.declare(channel, @exchange_name, :direct)

    for item <- items_to_sell do
      AMQP.Queue.declare(channel, item)
      AMQP.Queue.bind(channel, item, @exchange_name, routing_key: item)
    end

    AMQP.Basic.qos(channel, prefetch_count: 1)

    Enum.each(items_to_sell, fn item ->
      AMQP.Basic.consume(channel, item, self())
    end)

    IO.puts(" [x] Waiting for orders. To exit press CTRL+C")
    {:ok, %{channel: channel, deliver_name: deliver_name, id: 0, connection: connection}}
  end

  @impl true
  def handle_cast({:send, product_name}, state) do
    IO.puts(" [x] Sending answer for #{product_name}")
    AMQP.Basic.publish(state.channel, @exchange_name, product_name, state.team_name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    IO.puts(
      " [x] [#{state.deliver_name}] Received order for: #{payload}, exchange: #{meta.exchange}, routing_key: #{meta.routing_key}"
    )

    new_state = send_message(state, payload)
    AMQP.Basic.ack(state.channel, meta.delivery_tag)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, state) do
    IO.puts(" [x] Consumer registered with tag: #{consumer_tag}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag, nowait: nowait}}, state) do
    IO.puts(" [x] Consumer cancelled: tag=#{consumer_tag}, nowait=#{nowait}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_cancel_ok, %{consumer_tag: consumer_tag}}, state) do
    IO.puts(" [x] Consumer cancel confirmed: tag=#{consumer_tag}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts(" [x] Terminating deliver #{state.deliver_name} due to: #{inspect(reason)}")
    AMQP.Connection.close(state.connection)
    :ok
  end
end
