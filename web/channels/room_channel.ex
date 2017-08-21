defmodule Chat.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", message, socket) do
    IO.inspect message
    {:ok, socket}
  end

  def handle_in("new:msg", %{"body" => body, "user" => user} = params, socket) do
    IO.inspect params
    broadcast! socket, "new:msg", %{body: body, user: user}
    {:noreply, socket}
  end

  def handle_out("new:msg", payload, socket) do
    push socket, "new:msg", payload
    {:noreply, socket}
  end

end
