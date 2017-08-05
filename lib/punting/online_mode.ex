defmodule Punting.OnlineMode do
  use Connection

  defstruct ~w[connection timeout buffer]a

  @server 'punter.inf.ed.ac.uk'
  @receive_timeout 180000

  def start_link(port, opts, timeout \\ 120000) do
    Connection.start_link(__MODULE__, {@server, choose_port(port), opts, timeout})
  end
  
  def init({host, port, opts, timeout}) do
    s = %{host: host, port: port, opts: opts, timeout: timeout, sock: nil}
    {:connect, :init, s}
  end

  def send_data(conn, data), do: Connection.call(conn, {:send, data})
  def recv(conn, bytes, timeout \\ 60000), 
    do: Connection.call(conn, {:recv, bytes, timeout})
  def close(conn), do: Connection.call(conn, :close)

  def connect(_, %{sock: nil, host: host, port: port, opts: opts, timeout: timeout} = s) do
    IO.puts("ONLINE: connect")
    case :gen_tcp.connect(host, port, [active: false, mode: :binary, packet: :raw] ++ opts, timeout) do
      {:ok, sock} ->
        {:ok, %{s | sock: sock}}
      {:error, _} ->
        {:backoff, 1000, s}
    end
  end

  def disconnect(info, %{sock: sock} = s) do
    :ok = :gen_tcp.close(sock)
    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
      {:error, :closed} ->
        :error_logger.format("Connection closed~n", [])
      {:error, reason} ->
        reason = :inet.format_error(reason)
        :error_logger.format("Connection error: ~s~n", [reason])
    end
    {:connect, :reconnect, %{s | sock: nil}}
  end

  def handle_call(_, _, %{sock: nil} = s) do
    {:reply, {:error, :closed}, s}
  end
  
  def handle_call({:send, data}, _, %{sock: sock} = s) do
    case :gen_tcp.send(sock, data) do
      :ok ->
        {:reply, :ok, s}
      {:error, _} = error ->
        {:disconnect, error, error, s}
    end
  end
  def handle_call({:recv, bytes, timeout}, _, %{sock: sock} = s) do
    case :gen_tcp.recv(sock, bytes, timeout) do
      {:ok, _} = ok ->
        {:reply, ok, s}
      {:error, :timeout} = timeout ->
        {:reply, timeout, s}
      {:error, _} = error ->
        {:disconnect, error, error, s}
    end
  end
  def handle_call(:close, from, s) do
    {:disconnect, {:close, from}, s}
  end

  def handshake(conn, name) do
    IO.puts("ONLINE: send handshake message")
    send_json(IO.inspect(conn), %{"me" => name})
    %__MODULE__{connection: conn, buffer: ""}
  end

  def receive_message(%__MODULE__{connection: conn}) do
    {:ok, data} = recv(conn, 0, @receive_timeout)
    data
  end

  def send_ready(%__MODULE__{connection: conn}, id, _state) do
    send_json(conn, %{"ready" => id})
  end

  def send_move(%__MODULE__{connection: conn}, {id, source, target}, _state) do
    send_json(
      conn,
      %{"claim" => %{"punter" => id, "source" => source, "target" => target}}
    )
  end
  def send_move(%__MODULE__{connection: conn}, id, _state) do
    send_json(conn, %{"pass" => %{"punter" => id}})
  end

  def send_json(conn, message) do
    json = Poison.encode!(message)
    send_data(conn, "#{byte_size(json)}:#{json}")
  end

  defp choose_port(nil) do
    System.get_env("ICFP_PORT")
    |> String.to_integer
  end
  defp choose_port(port) when is_integer(port) do
    port
  end

  def deserialize(nil) do
    nil
  end
end
