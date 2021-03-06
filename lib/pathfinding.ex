defmodule Pathfinding do
  @moduledoc """
  Simple pathfinding module
  """

  alias Pathfinding.{
    Grid,
    Node,
    Search
  }

  def find_path(_, start_x, start_y, end_x, end_y, cost_threshold \\ nil)
  def find_path(_, start_x, start_y, end_x, end_y, _) when start_x == end_x and start_y == end_y, do: []
  def find_path(grid, start_x, start_y, end_x, end_y, cost_threshold) do
    case Grid.is_coord_stoppable(grid, end_x, end_y) do
      false -> nil
      true ->
        search = Search.new(start_x, start_y, end_x, end_y, cost_threshold)
        start_node =
          search
          |> Pathfinding.coordinate_to_node(nil, start_x, start_y, 0)
        search =
          search
          |> Search.push(start_node)
          |> Pathfinding.calculate(grid)

        case Search.pop(search) do
          {nil, _} -> nil
          {node, _} ->
            node
            |> Node.format_path()
        end
      end
  end

  def find_walkable(
    grid,
    x,
    y,
    cost_threshold \\ nil
  ) do
    search = Search.new(x, y, cost_threshold)
    start_node =
      search
      |> Pathfinding.coordinate_to_node(nil, x, y, 0)
    search =
      search
      |> Search.push(start_node)
      |> Pathfinding.calculate(grid)

    search
    |> Search.traversed_nodes()
    |> Enum.filter(&(Grid.is_coord_walkable(grid, &1.x, &1.y)))
    |> Enum.map(&(%{x: &1.x, y: &1.y}))
  end

  def calculate(%Search{} = search, %Grid{} = grid) do
    case Search.size(search) do
      0 -> search
      _ -> case reached_destination(search, Search.peek(search)) do
        true -> search
        false ->
          {node, search} = Search.pop(search)
          node = node |> Map.put(:visited, true)
          search = search |> Search.cache(node)

          search = case node.y > 0 do
            false -> search
            true -> Pathfinding.check_adjacent_node(search, grid, node, 0, -1)
          end
          search = case node.x < length(Enum.at(grid.tiles, node.y)) - 1 do
            false -> search
            true -> Pathfinding.check_adjacent_node(search, grid, node, 1, 0)
          end
          search = case node.y < length(grid.tiles) - 1 do
            false -> search
            true -> Pathfinding.check_adjacent_node(search, grid, node, 0, 1)
          end
          search = case node.x > 0 do
            false -> search
            true -> Pathfinding.check_adjacent_node(search, grid, node, -1, 0)
          end

          Pathfinding.calculate(search, grid)
        end
    end
  end
  defp reached_destination(%{end_x: end_x, end_y: end_y}, %{x: x, y: y}) do
    end_x == x && end_y == y
  end

  def check_adjacent_node(
    %Search{} = search,
    %Grid{} = grid,
    source_node,
    x,
    y
  ) do
    adjacent_x = source_node.x + x
    adjacent_y = source_node.y + y
    adjacent_cost = Grid.get_coord_cost(grid, adjacent_x, adjacent_y)

    case (
      Grid.is_coord_walkable(grid, adjacent_x, adjacent_y) &&
      Pathfinding.can_afford(source_node, adjacent_cost, search.cost_threshold)
    ) do
      false -> search
      true ->
        adjacent_node =
          search
          |> Pathfinding.coordinate_to_node(
            source_node,
            adjacent_x,
            adjacent_y,
            adjacent_cost
          )
        search =
          search
          |> Search.cache(adjacent_node)

        case adjacent_node.visited do
          false ->
            search
            |> Search.push(adjacent_node)
          true -> case source_node.cost + adjacent_cost < adjacent_node.cost do
            false -> search
            true ->
              adjacent_node =
                adjacent_node
                |> Map.put(:cost, source_node.cost + adjacent_cost)
                |> Map.put(:parent, source_node)

              search
              |> Search.update(adjacent_node)
          end
        end
    end
  end

  def can_afford(_, _, nil), do: true
  def can_afford(source_node, cost, cost_threshold) do
    source_node.cost + cost <= cost_threshold
  end

  def coordinate_to_node(
    search,
    parent,
    x,
    y,
    cost
  ) do
    case Search.get_node(search, x, y) do
      %Node{} = node -> node
      nil ->
        distance = case is_nil(search.end_x) && is_nil(search.end_y) do
          true -> 1
          false -> Pathfinding.get_distance(x, y, search.end_x, search.end_y)
        end

        %Node{
          parent: parent,
          x: x,
          y: y,
          cost: case Map.get(parent || %{}, :cost) do
            nil -> cost
            parent_cost -> parent_cost + cost
          end,
          distance: distance
        }
    end
  end

  def get_distance(x1, y1, x2, y2) do
    dx = abs(x1 - x2)
    dy = abs(y1 - y2)
    dx + dy
  end
end
