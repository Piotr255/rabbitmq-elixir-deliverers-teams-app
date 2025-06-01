defmodule Admin do
  use GenServer
  @deliverers_exchange "deliverers"
  @teams_exchange "teams"
  @exchange_name "orders"
  @queue_admin "admin"

  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: elem(options, 0))
  end

  @impl true
  def init(options) do
    {admin_name} = options
    {:ok, connection} = AMQP.Connection.open()
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Exchange.declare(channel, @deliverers_exchange, :fanout)
    AMQP.Exchange.declare(channel, @teams_exchange, :fanout)

    # # Get messages between deliverers and teams
    AMQP.Queue.declare(channel, @queue_admin)
    AMQP.Queue.bind(channel, @queue_admin, @exchange_name, routing_key: "#")
    AMQP.Basic.consume(channel, @queue_admin, self(), no_ack: true)

    IO.puts(" [x] Waiting for messages. To exit press CTRL+C")
    {:ok, %{channel: channel, admin_name: admin_name, connection: connection}}
  end

  def send_message_to_all(admin_name, message) do
    GenServer.cast(admin_name, {:send_all, message})
  end

  def send_message_to_teams(admin_name, message) do
    GenServer.cast(admin_name, {:send_teams, message})
  end

  def send_message_to_deliverers(admin_name, message) do
    GenServer.cast(admin_name, {:send_deliverers, message})
  end

  @impl true
  def handle_cast({:send_all, message}, state) do
    IO.puts(" [x] Sending message to all")
    AMQP.Basic.publish(state.channel, @teams_exchange, "", message)
    AMQP.Basic.publish(state.channel, @deliverers_exchange, "", message)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_teams, message}, state) do
    IO.puts(" [x] Sending message to teams")
    AMQP.Basic.publish(state.channel, @teams_exchange, "", message)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_deliverers, message}, state) do
    IO.puts(" [x] Sending message to deliverers")
    AMQP.Basic.publish(state.channel, @deliverers_exchange, "", message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    IO.puts(
      " [x] [#{state.admin_name}] Received: #{payload}, exchange: #{meta.exchange}, routing_key: #{meta.routing_key}"
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
    IO.puts(" [x] Terminating admin #{state.admin_name} due to: #{inspect(reason)}")
    AMQP.Connection.close(state.connection)
    :ok
  end
end
