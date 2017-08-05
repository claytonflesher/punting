defmodule StrategyFunctionalTest do
  use ExUnit.Case, async: true
  
  @moduletag :functional
  @moduletag :strategy

  test "slacker match" do
    IO.inspect(play_match(Punting.Strategy.AlwaysPass))
  end

  test "random match" do
    IO.inspect(play_match(Punting.Strategy.RandomChoice))
  end

  def play_match(strategy) do
    game = hd(Livegames.list_empty()
        |> Enum.filter( &(Enum.empty?(&1.extensions)) )
        |> Enum.filter( &(&1.map_name == "sample.json") ))
    IO.puts("Found a game with #{game.seats} seats.")
    Range.new(0, game.seats - 1)
    |> Enum.each(fn (n) -> 
        Task.async( fn -> go_play(n, game.port, strategy) end )
    end)

    IO.puts("Waiting for stop message")
    result = receive do
        {:stop, info} -> info
    end
    IO.puts("Found stop message")
    IO.inspect(result)
  end

  def go_play(n, port, strategy) do
      IO.puts("Starting player #{n} on port #{port}")
      Punting.Player.start_link(Punting.OnlineMode,
        [
          port: port,
          timeout: 120000,
          scores: self(), 
          strategy: strategy])
  end
end
