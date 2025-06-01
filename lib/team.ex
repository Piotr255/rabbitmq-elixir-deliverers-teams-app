defmodule Team do
  use GenServer
  @exchange_name "orders"

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: elem(options, 0))
  end

  @impl true
  def init(options) do
    {team_name} = options
    team_name = Atom.to_string(team_name)
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)
    AMQP.Queue.declare(channel, team_name)
    AMQP.Exchange.declare(channel, @exchange_name, :direct)

    AMQP.Queue.bind(channel, team_name, @exchange_name, routing_key: team_name)
    AMQP.Basic.consume(channel, team_name, self(), no_ack: true)
    IO.puts(" [x] Waiting for orders' answers. To exit press CTRL+C")
    {:ok, %{channel: channel, team_name: team_name, connection: connection}}
  end

  def send_message(product_name, team_name) do
    GenServer.cast(team_name, {:send, product_name})
  end

  @impl true
  def handle_cast({:send, product_name}, state) do
    IO.puts(" [x] Sending order for #{product_name}")
    AMQP.Basic.publish(state.channel, @exchange_name, product_name, state.team_name)
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    IO.puts(
      " [x] [#{state.team_name}] Received answer: #{payload}, exchange: #{meta.exchange}, routing_key: #{meta.routing_key}"
    )

    {:noreply, state}
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
    IO.puts(" [x] Terminating team #{state.team_name} due to: #{inspect(reason)}")
    AMQP.Connection.close(state.connection)
    :ok
  end
end
