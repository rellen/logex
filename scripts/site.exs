# The site's two checks beside ExDoc's own (decisions 546 and 548), run from the project's
# root, the first by `mix docs` before ExDoc reads a page and both by scripts/docs.sh:
#
#     elixir scripts/site.exs stage [<dir>]   # the pages, made ready for ExDoc
#     elixir scripts/site.exs check <log>     # the built site and the build's log
#
# `stage` reads docs/pages.exs, the list of pages, and writes each page of the site to
# `_build/docs/pages/<path>`, the copy ExDoc reads (or under `<dir>`, for a test), with its
# links made right for the site.
# A page is written to read on GitHub, where a link is relative to the page's own file,
# and ExDoc puts every page in one directory. So in the copy:
#
#   - a link to a page of the site is left as it is: ExDoc finds the page by its file name;
#   - a link to a picture under guides/assets/ is made `assets/<file>`, where ExDoc puts it;
#   - a link to any other file or directory of the repository, a page read on GitHub among
#     them, is made its address on GitHub, on `main`.
#
# It refuses, each as a line `<page>:<line>: ...` on stderr, and exits 1: a link to a file
# that is not there or is outside the repository; a link to an anchor no heading of level 2 or 3 of its page gives; a
# picture outside guides/assets/; two pages of the site with one file name, which ExDoc
# could not tell apart; and, in a page under the writing rules, a heading of level 2 or 3
# whose anchor on GitHub is not its anchor in the site, so that no link works in one place
# and not in the other. Text in a code block or a code span is not read.
#
# `check` reads what `mix docs` printed and the site it built in `doc/`. It gathers every
# warning of the build, `<where>: <message>`, and every dead link of every page built, a
# link to a file that is not in the site or to an anchor its page does not have, which
# ExDoc itself does not look for: `<page>: the link ...`. What it gathers must be the
# lines of docs/site-warnings.txt, each as often as the list has it: what the module text
# gives today, which DOC-2 clears. A warning or a dead link the list does not have, a
# page's or a module's, is refused, and so is a line of the list the build no longer
# gives. Each refusal is a line on stderr and the exit code is 1; with none it prints the
# count of pages, links and listed lines it read. A script, not a test: it uses
# `case` freely.
defmodule Site do
  @moduledoc false

  @manifest "docs/pages.exs"
  @staged "_build/docs/pages"
  @assets "guides/assets"
  @warnings "docs/site-warnings.txt"
  @github "https://github.com/rellen/logex"
  @fence ~r/^\s*(```+|~~~+)/
  @link ~r/(!?)\[([^\]]*)\]\(\s*([^)\s]+)(\s+"[^"]*")?\s*\)/
  @heading ~r/^(\#{1,6})\s+(.+?)\s*$/

  def staged, do: @staged
  def github, do: @github

  def pages do
    {pages, _} = Code.eval_file(@manifest)
    pages
  end

  def on_site(pages), do: for({path, _kind, group} <- pages, group != :github, do: path)

  # ---- stage ----

  def stage(out \\ @staged) do
    pages = pages()
    site = on_site(pages)
    kinds = Map.new(pages, fn {path, kind, _group} -> {path, kind} end)
    texts = Map.new(site, &{&1, File.read!(&1)})
    anchors = Map.new(texts, fn {path, text} -> {path, anchors(text)} end)

    {staged, refusals} =
      Enum.map_reduce(site, twice(site), fn path, refusals ->
        {text, found} = rewrite(path, texts[path], kinds[path], site, anchors)
        {{path, text}, refusals ++ found}
      end)

    case refusals do
      [] ->
        File.rm_rf!(out)

        for {path, text} <- staged do
          File.mkdir_p!(Path.dirname(Path.join(out, path)))
          File.write!(Path.join(out, path), text)
        end

        IO.puts("site: #{length(staged)} pages staged in #{out}")

      _ ->
        refuse(refusals)
    end
  end

  defp twice(site) do
    for {name, [_, _ | _] = paths} <- Enum.group_by(site, &Path.basename/1) do
      "#{Enum.join(paths, " and ")}: two pages of the site named #{name}; ExDoc tells " <>
        "pages apart by file name, so give one another name"
    end
  end

  # A page's text with each link made right for the site, and what is wrong with them.
  defp rewrite(path, text, kind, site, anchors) do
    {lines, refusals} =
      text
      |> prose_lines()
      |> Enum.map_reduce([], fn
        {line, _n, :code}, refusals ->
          {line, refusals}

        {line, n, :prose}, refusals ->
          {line, found} = links(line, n, path, site, anchors)
          {line, refusals ++ found ++ heading(line, n, path, kind)}
      end)

    {Enum.join(lines, "\n"), refusals}
  end

  # Each line with its number and whether it is prose or lies in a fenced code block or
  # an HTML comment.
  def prose_lines(text) do
    {lines, _} =
      text
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.map_reduce(nil, fn {line, n}, open ->
        case {open, Regex.run(@fence, line)} do
          {nil, [_, marker]} -> {{line, n, :code}, marker}
          {nil, nil} -> {{line, n, kind_of(line)}, nil}
          {marker, [_, closing]} -> {{line, n, :code}, closed(marker, closing, line)}
          {marker, nil} -> {{line, n, :code}, marker}
        end
      end)

    lines
  end

  defp closed(marker, closing, line) do
    if String.starts_with?(closing, marker) and String.trim(line) == closing,
      do: nil,
      else: marker
  end

  defp kind_of(line) do
    if String.match?(line, ~r/^\s*<!--.*-->\s*$/), do: :code, else: :prose
  end

  # A line with its code spans made runs of `x` of the same length, so that a bracket or
  # a parenthesis inside one is not read as a link's.
  def masked(line) do
    Regex.replace(~r/(`+)(.+?)\1(?!`)/, line, fn whole, _ticks, _inner ->
      String.duplicate("x", byte_size(whole))
    end)
  end

  defp links(line, n, path, site, anchors) do
    matches = Regex.scan(@link, masked(line), return: :index)

    {line, refusals} =
      matches
      |> Enum.reverse()
      |> Enum.reduce({line, []}, fn [_whole, {bang_at, bang_len}, _text, {at, len} | _],
                                    {line, refusals} ->
        target = binary_part(line, at, len)
        image? = bang_len == 1 and binary_part(line, bang_at, 1) == "!"

        case target(target, image?, path, site, anchors) do
          {:ok, ^target} ->
            {line, refusals}

          {:ok, new} ->
            {binary_part(line, 0, at) <>
               new <>
               binary_part(line, at + len, byte_size(line) - at - len), refusals}

          {:error, why} ->
            {line, ["#{path}:#{n}: #{why}" | refusals]}
        end
      end)

    {line, refusals}
  end

  defp target(target, image?, path, site, anchors) do
    uri = URI.parse(target)

    cond do
      uri.scheme != nil or String.starts_with?(target, "//") ->
        {:ok, target}

      uri.path in [nil, ""] ->
        anchor(path, uri.fragment, target, anchors)

      true ->
        file = resolve(path, URI.decode(uri.path))
        local(file, image?, uri.fragment, target, site, anchors)
    end
  end

  defp resolve(page, relative) do
    case Path.expand(Path.join(Path.dirname(page), relative)) |> Path.relative_to_cwd() do
      "." -> ""
      file -> file
    end
  end

  defp local(file, image?, fragment, target, site, anchors) do
    cond do
      not inside?(file) ->
        {:error, "the link `#{target}` leads out of the repository"}

      not File.exists?(file) ->
        {:error, "the link `#{target}` leads to #{shown(file)}, which is not there"}

      String.starts_with?(file, @assets <> "/") ->
        {:ok, "assets/" <> String.replace_prefix(file, @assets <> "/", "")}

      image? ->
        {:error, "the picture `#{target}` is outside #{@assets}/, where the site's pictures are"}

      file in site ->
        with {:ok, _} <- anchor(file, fragment, target, anchors), do: {:ok, target}

      true ->
        kind = if File.dir?(file), do: "tree", else: "blob"
        {:ok, "#{@github}/#{kind}/main/#{file}" <> fragment(fragment)}
    end
  end

  defp inside?(file), do: Path.type(file) == :relative and not String.starts_with?(file, "..")
  defp shown(""), do: "the repository's root"
  defp shown(file), do: file

  defp fragment(nil), do: ""
  defp fragment(fragment), do: "#" <> fragment

  defp anchor(_page, nil, target, _anchors), do: {:ok, target}

  defp anchor(page, fragment, target, anchors) do
    if fragment in anchors[page].github do
      {:ok, target}
    else
      {:error,
       "the link `#{target}` names the anchor ##{fragment}, which no heading of level 2 " <>
         "or 3 of #{page} gives"}
    end
  end

  # The anchors of a page's headings of level 2 and 3, as GitHub makes them and as ExDoc
  # does, a heading given twice numbered from its second.
  def anchors(text) do
    headings =
      for {line, _n, :prose} <- prose_lines(text),
          [_, marks, title] <- [Regex.run(@heading, line)],
          byte_size(marks) in [2, 3],
          do: plain(title)

    %{
      github: numbered(Enum.map(headings, &github/1)),
      exdoc: numbered(Enum.map(headings, &exdoc/1))
    }
  end

  # A heading's text as a reader sees it: no attribute list, no code or emphasis marks, a
  # link its text.
  def plain(title) do
    title
    |> String.replace(~r/\s*\{:[^}]*\}\s*$/, "")
    |> String.replace(~r/\[([^\]]*)\]\([^)]*\)/, "\\1")
    |> String.replace(~r/[`*]/, "")
    |> String.trim()
  end

  def github(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s_-]/u, "")
    |> String.replace(~r/\s/u, "-")
  end

  def exdoc(title) do
    title
    |> String.replace(~r/\W+/u, "-")
    |> String.trim("-")
    |> String.downcase()
  end

  defp numbered(ids) do
    {ids, _} =
      Enum.map_reduce(ids, %{}, fn id, seen ->
        count = Map.get(seen, id, 0)
        {if(count > 0, do: "#{id}-#{count}", else: id), Map.put(seen, id, count + 1)}
      end)

    ids
  end

  defp heading(_line, _n, _path, :legacy), do: []

  defp heading(line, n, path, _kind) do
    case Regex.run(@heading, line) do
      [_, marks, title] when byte_size(marks) in [2, 3] ->
        title = plain(title)

        if github(title) == exdoc(title) do
          []
        else
          [
            "#{path}:#{n}: the heading `#{title}` is ##{github(title)} on GitHub and " <>
              "##{exdoc(title)} in the site; write it with letters, digits and single " <>
              "spaces alone, so that a link to it works in both"
          ]
        end

      _ ->
        []
    end
  end

  # ---- check ----

  def check(log) do
    {given, listed} = {warnings(File.read!(log)), listed()}
    pages = Path.wildcard("doc/*.html")
    ids = Map.new(pages, &{Path.basename(&1), ids(File.read!(&1))})
    links = for page <- pages, link <- hrefs(File.read!(page)), do: {Path.basename(page), link}

    given = given ++ Enum.flat_map(links, &dead(&1, ids))

    refusals =
      for(w <- given -- listed, do: "not in #{@warnings}: #{w}") ++
        for(
          w <- listed -- given,
          do: "#{@warnings} lists what the build no longer gives; take its line out: #{w}"
        ) ++
        if(pages == [], do: ["no page in doc/: the site was not built"], else: [])

    case refusals do
      [] ->
        IO.puts(
          "site: #{length(pages)} pages built, #{length(links)} links followed, " <>
            "#{length(given)} warnings and dead links, each listed in #{@warnings}"
        )

      _ ->
        refuse(refusals)
    end
  end

  # Each warning a build printed, `<where>: <message>`, its place given by what it is in,
  # a module, a function or a page, never by a line number, which moves.
  def warnings(log) do
    lines = String.split(log, "\n")

    for {line, at} <- Enum.with_index(lines),
        [_, message] <- [Regex.run(~r/^\s*warning: (.*)$/, line)] do
      where =
        lines
        |> Enum.drop(at + 1)
        |> Enum.take_while(&(not String.match?(&1, ~r/^\s*warning: /)))
        |> Enum.find_value("", fn line ->
          case Regex.run(~r/^\s*└─ (.*)$/u, line) do
            [_, where] -> where(where)
            nil -> nil
          end
        end)

      String.trim("#{where}: #{message}", ": ")
    end
  end

  defp where(where) do
    where
    |> String.replace(~r/^\(logex [^)]*\) /, "")
    |> String.replace(@staged <> "/", "")
    |> String.replace(~r/^lib\/\S+?\.ex:\d+(:\d+)?: /, "")
    |> String.replace(~r/: \(file\)$/, "")
    |> String.replace(~r/:\d+(:\d+)?$/, "")
  end

  def listed do
    for line <- String.split(File.read!(@warnings), "\n"),
        line = String.trim(line),
        line != "" and not String.starts_with?(line, "#"),
        do: line
  end

  defp ids(html) do
    for [_, id] <- Regex.scan(~r/\sid="([^"]*)"/, html), into: MapSet.new(), do: unescape(id)
  end

  defp hrefs(html) do
    for [_, link] <- Regex.scan(~r/\s(?:href|src)="([^"]*)"/, html), do: unescape(link)
  end

  defp unescape(text) do
    text
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
  end

  defp dead({page, link}, ids) do
    uri = URI.parse(link)

    cond do
      uri.scheme != nil or String.starts_with?(link, "//") ->
        []

      uri.path in [nil, ""] ->
        missing(page, page, uri.fragment, link, ids)

      true ->
        file = URI.decode(uri.path)

        cond do
          Map.has_key?(ids, file) -> missing(page, file, uri.fragment, link, ids)
          File.exists?(Path.join("doc", file)) -> []
          # ExDoc's own, on every page: a host of several versions puts the file there.
          file == "docs_config.js" -> []
          true -> ["#{page}: the link `#{link}` leads to #{file}, which is not in the site"]
        end
    end
  end

  defp missing(_page, _file, fragment, _link, _ids) when fragment in [nil, ""], do: []

  defp missing(page, file, fragment, link, ids) do
    if URI.decode(fragment) in ids[file] or fragment in ids[file] do
      []
    else
      [
        "#{page}: the link `#{link}` names an anchor that #{file} does not have"
      ]
    end
  end

  defp refuse(refusals) do
    Enum.each(refusals, &IO.puts(:stderr, "site: " <> &1))
    System.halt(1)
  end
end

case System.argv() do
  ["stage"] ->
    Site.stage()

  ["stage", out] ->
    Site.stage(out)

  ["check", log] ->
    Site.check(log)

  _ ->
    IO.puts(:stderr, "usage: elixir scripts/site.exs stage [<dir>] | check <log>")
    System.halt(2)
end
