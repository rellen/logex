defmodule Logex.FbType.Builtins do
  # The table `Logex.FbType.builtins/0` gives, built once when logex compiles, so that
  # looking a type word up costs a map's lookup and builds nothing (M5-5's review: built
  # on every call, its 22 entries made a compile 3.3x dearer). It is built here, not in
  # `Logex.FbType`, since a module cannot build its own structs while it compiles.
  @moduledoc false

  @table Logex.FbType.built()

  def table, do: @table
end
