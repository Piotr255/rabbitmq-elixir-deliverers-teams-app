defmodule RabbitmqTutorials.MixProject do
  use Mix.Project

  def project do
    [
      app: :rabbitmq_tutorials,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [applications: [:amqp]]
  end

  def deps do
    [
      {:amqp, "~> 4.0"}
    ]
  end
end
