# Simple RabbitMQ Elixir Application to communicate teams and their deliverers

### Function to use with `iex -S mix`

- `{:ok, pid1} = Deliverer.start_link({:deliver1, ["oxygen", "shoes"]})`
- `{:ok, pid2} = Deliverer.start_link({:deliver2, ["oxygen", "backpack"]})`
- `{:ok, pid1} = Team.start_link({:team1})`
- `{:ok, pid2} = Team.start_link({:team2})`
- `Team.send_message("oxygen", :team1)`
- `Team.send_message("oxygen", :team2)`
- `Team.send_message("shoes", :team1)`
- `Team.send_message("shoes", :team2)`
- `Team.send_message("backpack", :team1)`
- `Team.send_message("backpack", :team2)`
- `{:ok, pid1} = Admin.start_link({:admin1})`
- `{:ok, pid2} = Admin.start_link({:admin2})`
- `GenServer.stop(pid1)`
- `GenServer.stop(pid2)`

## Installation

- `mix deps.get`
- `mix deps.compile`

## Diagram

```mermaid
---
config:
  theme: redux
  look: neo
  layout: elk
---
flowchart TD
    order_exchange("Order exchange - topic") --> team1_queue["Team1 queue"] & team2_queue["Team2 queue"] & oxygen_queue["Oxygen queue"] & shoes_queue["Shoes queue"] & backpack_queue["Backpack queue"] & admin_queue["Admin queue - #"]
    team1_queue --> team1(["Team 1"])
    team2_queue --> team2(["Team 2"])
    random_queue1_team("Random queue for team1 {admin}") --> team1 & team1
    random_queue2_team("Random queue for team2 {admin}") --> team2
    team1 --> order_exchange
    team2 --> order_exchange
    admin_queue --> admin(["Admin"])
    shoes_queue -.-> deliverer1(["Deliverer 1"]) & deliverer2(["Deliverer 2"])
    oxygen_queue -.-> deliverer1 & deliverer2
    backpack_queue -.-> deliverer1 & deliverer2
    admin --> teams_exchange("Teams exchange - fanout") & deliverer_exchange("Deliverer exchange - fanout")
    teams_exchange --> random_queue1_team & random_queue2_team
    deliverer_exchange --> random_queue1_deliverer("Random queue for deliverer1 {admin}") & random_queue2_deliverer("Random queue for deliverer2 {admin}")
    random_queue1_deliverer --> deliverer1
    random_queue2_deliverer --> deliverer2

```
