defmodule CGenServer do
  @moduledoc """
  Handwritten implementation of GenServer, just to explain how GenServer works.

  ## Examples

      iex> pid = TodoServer.start
      iex> entry = %{title: "cure covid-19", date: ~D[2020-10-10]}
      %{date: ~D[2020-10-10], title: "cure covid-19"}
      iex> pid |> TodoServer.add_todo(entry)
      {:cast, {:add_todo, %{date: ~D[2020-10-10], title: "cure covid-19"}}}
      iex> pid |> TodoServer.get_todos(entry.date)
      [%{date: ~D[2020-10-10], id: 0, title: "cure covid-19"}]

  """
  def start(module) do
    spawn(fn ->
      init_state = module.init()
      loop(module, init_state)
    end)
  end

  defp loop(module, current_state) do
    receive do
      {:call, request, caller} ->
        {response, new_state} = module.handle_call(request, current_state)

        send(caller, {:response, response})
        loop(module, new_state)

      {:cast, request} ->
        new_state = module.handle_cast(request, current_state)

        loop(module, new_state)
    end
  end

  def call(server_pid, request) do
    send(server_pid, {:call, request, self()})

    receive do
      {:response, response} -> response
    end
  end

  def cast(server_pid, request) do
    send(server_pid, {:cast, request})
  end
end

defmodule TodoList do
  defstruct id: 0, entries: %{}

  def new(entries \\ []) do
    Enum.reduce(entries, %TodoList{}, fn entry, acc -> add_todo(acc, entry) end)
  end

  def add_todo(todo_list, entry) do
    entry = Map.put(entry, :id, todo_list.id)

    new_entries = Map.put(todo_list.entries, todo_list.id, entry)

    %TodoList{todo_list | entries: new_entries, id: todo_list.id + 1}
  end

  def get_todos(todo_list, date) do
    todo_list.entries
    |> Stream.filter(fn {_, entry} -> entry.date == date end)
    |> Enum.map(fn {_, entry} -> entry end)
  end

  def update_todo(todo_list, %{} = new_entry) do
    update_todo(todo_list, new_entry.id, fn _ -> new_entry end)
  end

  def update_todo(todo_list, entry_id, update_fn) do
    case Map.fetch(todo_list.entries, entry_id) do
      :error ->
        todo_list

      {:ok, old_entry} ->
        new_entry = update_fn.(old_entry)

        new_entries = Map.put(todo_list.entries, new_entry.id, new_entry)

        %TodoList{todo_list | entries: new_entries}
    end
  end
end

defmodule TodoServer do
  ## client:
  def start do
    CGenServer.start(TodoServer)
  end

  def add_todo(server_pid, new_entry) do
    CGenServer.cast(server_pid, {:add_todo, new_entry})
  end

  def get_todos(server_pid, date) do
    CGenServer.call(server_pid, {:get_todos, date})
  end

  ## server:
  def init do
    TodoList.new()
  end

  def handle_call({:get_todos, date}, todo_list) do
    {TodoList.get_todos(todo_list, date), todo_list}
  end

  def handle_cast({:add_todo, new_entry}, todo_list) do
    TodoList.add_todo(todo_list, new_entry)
  end
end
