# The site's two checks beside ExDoc's own (decisions 546 and 548), run from the project's
# root, the first by `mix docs` before ExDoc reads a page and both by scripts/docs.sh:
#
#     elixir scripts/site.exs stage [<dir>]   # the pages, made ready for ExDoc
#     elixir scripts/site.exs check <log>     # the built site and the build's log
#
# `stage` reads docs/pages.exs, the list of pages, and writes each page of the site to
# `_build/docs/pages/<name>`, the copy ExDoc reads (or under `<dir>`, for a test), under
# its name in the site and with its links made right for the site. A page is written to
# read on GitHub, where a link is relative to the page's own file and names a heading by
# GitHub's anchor; ExDoc puts every page in one directory, tells pages apart by file name
# and gives a heading its own anchor. So:
#
#   - a page's name in the site is `Page.name/1`'s (scripts/page.exs): a user's page, under
#     guides/, its file's name, any other page its whole path, `docs-style-guide.md`, so
#     that two pages with one file name in two directories are two pages of the site;
#   - a link to a page of the site is made the page ExDoc builds of that name,
#     `docs-style-guide.html`, and the anchor it names, GitHub's, is made the anchor ExDoc
#     gives the same heading: a heading may hold a function's name or a dotted name,
#     `Logex.compile/2`, which the two write differently. ExDoc's own reading of a link
#     to a page is by the file name the page has in the repository, which two pages can
#     share, so the stage leaves it no link to read;
#   - a link to a picture under guides/assets/ is made `assets/<file>`, where ExDoc puts it;
#   - a link to any other file or directory of the repository, a page read on GitHub among
#     them, is made its address on GitHub, on `main`.
#
# It refuses, each as a line `<page>:<line>: ...` on stderr, and exits 1: a link to a file
# that is not there or is outside the repository; a link to an anchor that no heading of
# level 2 or 3 of a page of the site gives, or no heading of a Markdown file read on
# GitHub; a picture outside guides/assets/; and two pages of the site with one name. Text
# in a code block or a code span is not read, and the blocks are scripts/page.exs's to
# find. A link to another site is not followed.
#
# `check` reads what `mix docs` printed and the site it built in `doc/`. It gathers every
# warning of the build, `<where>: <message>`, and every dead link of every page built, a
# link to a file that is not in the site or to an anchor its page does not have, which
# ExDoc itself does not look for: `<page>: the link ...`. What it gathers must be the
# lines of docs/site-warnings.txt, each as often as the list has it: what the module text
# gives today, which DOC-2 clears. A warning or a dead link the list does not have, a
# page's or a module's, is refused, and so is a line of the list the build no longer
# gives. Each refusal is a line on stderr and the exit code is 1; with none it prints the
# count of pages, links and listed lines it read. A script, not a test: it uses `case`,
# and function clauses for the rest.
Code.require_file("page.exs", __DIR__)

defmodule Site do
  @moduledoc false

  @staged "_build/docs/pages"
  @assets "guides/assets"
  @warnings "docs/site-warnings.txt"
  @github "https://github.com/rellen/logex"
  @link ~r/(!?)\[([^\]]*)\]\(\s*([^)\s]+)(\s+"[^"]*")?\s*\)/
  @heading ~r/^(\#{1,6})\s+(.+?)\s*$/
  @markdown [".md", ".cheatmd", ".livemd"]

  def staged, do: @staged
  def github, do: @github

  def on_site(pages), do: for({path, _kind, group} <- pages, group != :github, do: path)

  # ---- stage ----

  def stage(out \\ @staged) do
    site = on_site(Page.listed())
    texts = Map.new(site, &{&1, File.read!(&1)})
    anchors = Map.new(texts, fn {path, text} -> {path, anchors(text, [2, 3])} end)
    context = %{site: site, anchors: anchors}

    {staged, refusals} =
      Enum.map_reduce(site, twice(site), fn path, refusals ->
        {text, found} = rewrite(path, texts[path], context)
        {{Page.name(path), text}, refusals ++ found}
      end)

    staged(refusals, staged, out)
  end

  defp staged([], staged, out) do
    File.rm_rf!(out)
    File.mkdir_p!(out)
    for {name, text} <- staged, do: File.write!(Path.join(out, name), text)
    IO.puts("site: #{length(staged)} pages staged in #{out}")
  end

  defp staged(refusals, _staged, _out), do: refuse(refusals)

  defp twice(site) do
    for {name, [_, _ | _] = paths} <- Enum.group_by(site, &Page.name/1) do
      "#{Enum.join(paths, " and ")}: two pages of the site named #{name}; ExDoc tells " <>
        "pages apart by file name, so give one another name"
    end
  end

  # A page's text with each link made right for the site, and what is wrong with them.
  defp rewrite(path, text, context) do
    {lines, refusals} =
      text
      |> Page.read()
      |> Page.lines()
      |> Enum.map_reduce([], fn
        {n, line, :prose}, refusals ->
          {line, found} = links(line, n, path, context)
          {line, refusals ++ found}

        {_n, line, _kind}, refusals ->
          {line, refusals}
      end)

    {Enum.join(lines, "\n"), refusals}
  end

  defp links(line, n, path, context) do
    Page.masked(line)
    |> then(&Regex.scan(@link, &1, return: :index))
    |> Enum.reverse()
    |> Enum.reduce({line, []}, fn [_whole, {bang_at, bang_len}, _text, {at, len} | _],
                                  {line, refusals} ->
      target = binary_part(line, at, len)
      image? = bang_len == 1 and binary_part(line, bang_at, 1) == "!"

      case target(target, image?, path, context) do
        {:ok, new} ->
          {binary_part(line, 0, at) <>
             new <>
             binary_part(line, at + len, byte_size(line) - at - len), refusals}

        {:error, why} ->
          {line, ["#{path}:#{n}: #{why}" | refusals]}
      end
    end)
  end

  defp target(target, image?, path, context) do
    uri = URI.parse(target)

    placed(
      uri.scheme != nil or String.starts_with?(target, "//"),
      uri.path in [nil, ""],
      {uri, target, image?, path},
      context
    )
  end

  # A link to another site is left; a link to a heading of its own page is made the
  # heading's anchor in the site; any other is a file's.
  defp placed(true, _own, {_uri, target, _image?, _path}, _context), do: {:ok, target}

  defp placed(false, true, {uri, target, _image?, path}, context),
    do: anchor(path, uri.fragment, target, context.anchors)

  defp placed(false, false, {uri, target, image?, path}, context) do
    file = resolve(path, URI.decode(uri.path))

    local(
      {inside?(file), File.exists?(file), String.starts_with?(file, @assets <> "/"), image?,
       file in context.site},
      file,
      uri.fragment,
      target,
      context
    )
  end

  defp resolve(page, relative),
    do:
      page
      |> Path.dirname()
      |> Path.join(relative)
      |> Path.expand()
      |> Path.relative_to_cwd()
      |> rooted()

  defp rooted("."), do: ""
  defp rooted(file), do: file

  # Where a link to a file leads: `{inside the repository, there, a picture's place, a
  # picture, a page of the site}`.
  defp local({false, _there, _asset, _image?, _page}, _file, _fragment, target, _context),
    do: {:error, "the link `#{target}` leads out of the repository"}

  defp local({true, false, _asset, _image?, _page}, file, _fragment, target, _context),
    do: {:error, "the link `#{target}` leads to #{shown(file)}, which is not there"}

  defp local({true, true, true, _image?, _page}, file, _fragment, _target, _context),
    do: {:ok, "assets/" <> String.replace_prefix(file, @assets <> "/", "")}

  defp local({true, true, false, true, _page}, _file, _fragment, target, _context),
    do: {:error, "the picture `#{target}` is outside #{@assets}/, where the site's pictures are"}

  defp local({true, true, false, false, true}, file, fragment, target, context) do
    with {:ok, anchor} <- anchor(file, fragment, target, context.anchors),
         do: {:ok, page(file) <> anchor}
  end

  defp local({true, true, false, false, false}, file, fragment, target, _context) do
    with :ok <-
           on_github(
             Path.extname(file) in @markdown and File.regular?(file),
             file,
             fragment,
             target
           ),
         do: {:ok, "#{@github}/#{tree(File.dir?(file))}/main/#{file}" <> fragment(fragment)}
  end

  # The page ExDoc builds of a page of the site: its name there as ExDoc makes an id of
  # it, `docs-README.md` the page `docs-readme.html`.
  def page(path), do: exdoc(Path.rootname(Page.name(path))) <> ".html"

  defp tree(true), do: "tree"
  defp tree(false), do: "blob"

  defp inside?(file), do: Path.type(file) == :relative and not String.starts_with?(file, "..")
  defp shown(""), do: "the repository's root"
  defp shown(file), do: file

  defp fragment(nil), do: ""
  defp fragment(fragment), do: "#" <> fragment

  # The anchor a link names, GitHub's, as the site has it: `#` and the anchor ExDoc gives
  # the same heading, or nothing where the link names none.
  defp anchor(_page, nil, _target, _anchors), do: {:ok, ""}

  defp anchor(page, fragment, target, anchors) do
    %{github: github, exdoc: exdoc} = anchors[page]
    named(Enum.find_index(github, &(&1 == fragment)), exdoc, page, fragment, target)
  end

  defp named(nil, _exdoc, page, fragment, target) do
    {:error,
     "the link `#{target}` names the anchor ##{fragment}, which no heading of level 2 " <>
       "or 3 of #{page} gives"}
  end

  defp named(at, exdoc, _page, _fragment, _target), do: {:ok, "#" <> Enum.at(exdoc, at)}

  # A link to a Markdown file read on GitHub names a heading of it, of any level, by
  # GitHub's anchor, or none.
  defp on_github(_markdown, _file, nil, _target), do: :ok
  defp on_github(false, _file, _fragment, _target), do: :ok

  defp on_github(true, file, fragment, target),
    do: given(fragment in anchors(File.read!(file), 1..6).github, file, fragment, target)

  defp given(true, _file, _fragment, _target), do: :ok

  defp given(false, file, fragment, target) do
    {:error,
     "the link `#{target}` names the anchor ##{fragment}, which no heading of #{file} gives"}
  end

  # The anchors of a page's headings of the levels given, as GitHub makes them and as
  # ExDoc does, a heading given twice numbered from its second.
  def anchors(text, levels) do
    headings =
      for {_n, line, :prose} <- Page.lines(Page.read(text)),
          [_, marks, title] <- [Regex.run(@heading, line)],
          byte_size(marks) in levels,
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
    |> String.replace(~r/&#\d+;|&[A-Za-z0-9]+;/, "")
    |> String.replace(~r/\W+/u, "-")
    |> String.trim("-")
    |> String.downcase()
  end

  defp numbered(ids) do
    {ids, _} =
      Enum.map_reduce(ids, %{}, fn id, seen ->
        {again(id, Map.get(seen, id, 0)), Map.update(seen, id, 1, &(&1 + 1))}
      end)

    ids
  end

  defp again(id, 0), do: id
  defp again(id, count), do: "#{id}-#{count}"

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
        ) ++ unbuilt(pages)

    checked(refusals, pages, links, given)
  end

  defp unbuilt([]), do: ["no page in doc/: the site was not built"]
  defp unbuilt(_pages), do: []

  defp checked([], pages, links, given) do
    IO.puts(
      "site: #{length(pages)} pages built, #{length(links)} links followed, " <>
        "#{length(given)} warnings and dead links, each listed in #{@warnings}"
    )
  end

  defp checked(refusals, _pages, _links, _given), do: refuse(refusals)

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
        |> Enum.find_value("", &place(Regex.run(~r/^\s*└─ (.*)$/u, &1)))

      String.trim("#{where}: #{message}", ": ")
    end
  end

  defp place(nil), do: nil

  defp place([_, where]) do
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

    followed(
      uri.scheme != nil or String.starts_with?(link, "//"),
      uri.path in [nil, ""],
      {page, link, uri},
      ids
    )
  end

  defp followed(true, _own, _link, _ids), do: []

  defp followed(false, true, {page, link, uri}, ids),
    do: missing(page, page, uri.fragment, link, ids)

  defp followed(false, false, {page, link, uri}, ids) do
    file = URI.decode(uri.path)

    built(
      Map.has_key?(ids, file),
      File.exists?(Path.join("doc", file)),
      file,
      {page, link, uri},
      ids
    )
  end

  defp built(true, _there, file, {page, link, uri}, ids),
    do: missing(page, file, uri.fragment, link, ids)

  defp built(false, true, _file, _link, _ids), do: []

  defp built(false, false, file, {page, link, _uri}, _ids),
    do: ["#{page}: the link `#{link}` leads to #{file}, which is not in the site"]

  defp missing(_page, _file, fragment, _link, _ids) when fragment in [nil, ""], do: []

  defp missing(page, file, fragment, link, ids),
    do: lost(URI.decode(fragment) in ids[file] or fragment in ids[file], page, file, link)

  defp lost(true, _page, _file, _link), do: []

  defp lost(false, page, file, link),
    do: ["#{page}: the link `#{link}` names an anchor that #{file} does not have"]

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
