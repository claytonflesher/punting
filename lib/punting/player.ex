defmodule Punting.Player do
  use GenServer

  defstruct mode:       nil,
            mode_arg:   nil,
            mode_state: nil,
            strategy:   Punting.Strategy.AlwaysPass,
            scores:     :halt,
            buffer:     "",
            game:       nil

  ### Server

  def start_link(Punting.OnlineMode, options) do
    {:ok, conn} = Punting.OnlineMode.start_link(options[:port], options, options[:timeout])
    GenServer.start_link(
      __MODULE__,
      {Punting.OnlineMode, conn, options[:strategy], options[:scores] || :halt}
    )
  end
  def start_link(mode, options \\ [ ]) do
    GenServer.start_link(
      __MODULE__,
      {mode, options[:mode_arg], options[:strategy], options[:scores] || :halt}
    )
  end

  ### Client

  def init({mode, mode_arg, strategy, scores}) do
    IO.puts("init player")
    send(self(), :handshake)
    {:ok, %__MODULE__{mode: mode, mode_arg: mode_arg, strategy: strategy, scores: scores}, :hibernate}
  end

  def handle_info(:handshake, %{mode: mode, mode_arg: mode_arg} = player) do
    IO.puts("handshake player")
    mode_state = mode.handshake(mode_arg, "The Mikinators")
    send(self(), :process_message)
    {:noreply, %__MODULE__{player | mode_state: mode_state}}
  end

  def handle_info(
    :process_message,
    %{mode: mode, mode_state: mode_state, buffer: buffer} = player
  ) do
    message    = mode.receive_message(mode_state)
    new_player = process_messages(buffer <> message, player)
    if is_nil(new_player) do
      {:stop, :normal, nil}
    else
      send(self(), :process_message)
      {:noreply, new_player}
    end
  end

  ### Helpers

  defp process_messages(buffer, player) do
    case Punting.Parser.parse(buffer) do
      {nil, ^buffer} ->
        %__MODULE__{player | buffer: buffer}
      {message, remainder} ->
        new_game = process_message(message, player)
        if is_tuple(message) && elem(message, 0) == :stop do
          nil
        else
          if remainder == "" do
            %__MODULE__{player | buffer: "", game: new_game}
          else
            process_messages(remainder, player)
          end
        end
    end
  end

  defp process_message({:setup, _id, _punters, _map} = setup, player) do
    new_game = DataStructure.process(setup)
    player.mode.send_ready(player.mode_state, new_game["id"], new_game)
    new_game
  end
  defp process_message({:move, moves, state}, player) do
    new_game =
      DataStructure.process(
        {
          :move,
          moves,
          player.mode.deserialize(state) || player.game
        }
      )
    move =
      case player.strategy.move(new_game) do
        nil              -> new_game["id"]
        {source, target} -> {new_game["id"], source, target}
        _                -> raise "Error:  Bad strategy:  #{player.strategy}"
      end
    player.mode.send_move(player.mode_state, move, new_game)
    new_game
  end
  defp process_message({:stop, _moves, _scores, _state} = message, player) do
    case player.scores do
      pid when is_pid(pid) ->
        send(pid, message)
      :halt ->
        IO.inspect(message)
        System.halt
    end
    player.game
  end
  defp process_message(_message, player), do: player.game
end
