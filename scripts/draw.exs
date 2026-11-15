# Draws the pictures the pages name, with scripts/pictures.exs (which says what a picture
# is and how a page names one). Run from the project's root, through Mix, since a picture
# is drawn by logex itself:
#
#     mix run scripts/draw.exs                 # every picture of every page of docs/pages.exs
#     mix run scripts/draw.exs <page>...       # the pictures of those pages
#     mix run scripts/draw.exs --check [<page>...]   # draw nothing: say which differ
#     mix run scripts/draw.exs --rung <file.ld> <out.svg> [<rung>...]   # one drawing, for a look
#     mix run scripts/draw.exs --timing <description.exs> <out.svg>     # one diagram, for a look
#
# For each picture it prints `drawn <svg>`, or `same <svg>` where the file already holds
# what the script gives. A mark that is wrong, or a source that cannot be drawn, is a line
# on stderr, `<page>:<line>: ...`, and the exit code is 1; with `--check` a picture that
# differs from its file is one too. test/logex/pictures_test.exs holds every picture to
# this script's output, so a picture cannot go stale. A script, not a test: it uses `case`
# freely.
Code.require_file("pictures.exs", __DIR__)

defmodule Draw do
  @moduledoc false

  def main(["--rung", source, out | rungs]),
    do: one(Pictures.Rung.svg(source, Enum.map(rungs, &String.to_integer/1)), out)

  def main(["--timing", source, out]), do: one(Pictures.Timing.svg(source), out)

  def main(["--check" | pages]), do: pages(pages, false)
  def main(pages), do: pages(pages, true)

  defp one({:ok, svg}, out) do
    File.write!(out, svg)
    IO.puts("drawn #{out}")
  end

  defp one({:error, why}, _out) do
    IO.puts(:stderr, "draw: #{why}")
    System.halt(1)
  end

  defp pages(pages, write?) do
    pages =
      case pages do
        [] ->
          {listed, _} = Code.eval_file("docs/pages.exs")
          for {path, kind, _group} <- listed, kind != :legacy or path == "README.md", do: path

        pages ->
          pages
      end

    problems =
      for page <- pages do
        {pictures, problems} = Pictures.of(page, File.read!(page))
        problems ++ Enum.flat_map(pictures, &picture(&1, page, write?))
      end

    case List.flatten(problems) do
      [] ->
        :ok

      problems ->
        Enum.each(problems, &IO.puts(:stderr, "draw: " <> &1))
        System.halt(1)
    end
  end

  defp picture({line, svg, _kind, _source, _rungs} = picture, page, write?) do
    case {Pictures.draw(picture), File.read(svg), write?} do
      {{:error, why}, _, _} ->
        ["#{page}:#{line}: #{why}"]

      {{:ok, text}, {:ok, text}, _} ->
        IO.puts("same #{svg}")
        []

      {{:ok, text}, _, true} ->
        File.mkdir_p!(Path.dirname(svg))
        File.write!(svg, text)
        IO.puts("drawn #{svg}")
        []

      {{:ok, _text}, _, false} ->
        [
          "#{page}:#{line}: #{svg} is not what its script gives: run `mix run scripts/draw.exs #{page}`"
        ]
    end
  end
end

Draw.main(System.argv())
