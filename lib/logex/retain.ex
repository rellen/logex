defmodule Logex.Retain do
  @moduledoc false
  # M6-5 (docs/organisation.md §4.13, decisions 275, 276, 285 and 312): the store, the file
  # on the host's disk that stands in for battery-backed memory. Internal: `Logex.Runner`
  # alone reads and writes it, the core staying pure (decision 282), and a resource's
  # retained image, `Logex.Runtime.retained/1`'s, is what it holds.
  #
  # Its text is decision 276's, a person's to read after an incident and, where decision
  # 284 has it, to edit by hand, since decision 355 (RV-5) of version 2 and since decision
  # 530 (RV-26), as every store the runner writes names its program, of version 3:
  #
  #     logex retain 3
  #     configuration plant written 2026-10-27T14:00:00Z
  #     resource 3c59dc048e8850243be8079a5c74d079
  #     program motor 7d793037a0760186574b0282f2f435e7
  #     global total_boxes dint 41
  #     trigger arm 0
  #     instance m1 motor
  #     m1.boxes ctu
  #     m1.boxes.cu bool 1
  #     m1.boxes.cv dint 41
  #     m1.weights int[8] 0 0 12 14 0 0 0 0
  #     end 12 lines
  #
  # a header, `logex retain 3`; the configuration's name and the time of the write on the
  # host's wall clock, in UTC to the second, for a person and for `status/1`, never for a
  # timer; since decision 517 (c) (RV-21) the program the runner ran as it wrote the store,
  # `resource <digest>`, of the configuration's own lines, and `program <type> <digest>`,
  # of each program type's text, in name order, since decision 527 (RV-26) as
  # `Logex.Printer` prints it and since decision 532 (RV-27) with each word logex reads in
  # any case lowercased and a literal bit number in brackets the plain bit, `XIC` and
  # `w.[4]` read as `xic` and `w.4` (written_by/1), which a warm fresh start lays beside the
  # program it is given and warns where they differ (warning/3), a store written before
  # RV-21 naming none and read as it was, and one that names a type and no resource
  # refused, each line read wherever it stands (decision 531); since decision 530 (RV-26)
  # the header `logex retain 3`, where RV-21 wrote these lines under `logex retain 2`, so
  # that a logex before RV-26 says plainly that it does not read the store's version, where
  # one before RV-21 told its `resource` line as one before any `instance` line. A store of
  # `logex retain 2` that names its program, RV-21's, names each type by its text's bytes,
  # and is laid beside the start's program digested so (compared/3, decision 534); one of
  # `logex retain 3` that names none, a hand edit's, is refused at its first line, as one
  # that names it in part is (decision 535, RV-27), where it was read as naming none;
  # encode/2, which names no program, writes `logex retain 2`; each retained global, `global
  # <name> <type> <value>`; since decision 313 each
  # retained `single`'s last sample, `trigger <name> <sample>`, and since RV-3's review a
  # task's own where it is not its trigger's, `trigger <task> <sample>` (decision 350); and
  # each instance whose
  # program retains anything, `instance <name> <program type>`, followed by its lines in
  # path order (`Logex.Image.ordered/1`), each instance on the way to a value `<path>
  # <kind>`, an array of instances `m1.lane_t ton[4]`, and each value `<path> <type>
  # <value>`, an array's elements in the elements' order, the rightmost subscript fastest,
  # each path the instance's name and then the path inside it, an element by its
  # subscripts' values (decision 312). An integer and a bool are written in decimal, a real
  # in the shortest text that reads back to it, a single's for a `real` (`Logex.Real.
  # spelled/2`), and a timer's `last` never (decision 273).
  #
  # The end line (decision 355): a store's last line is `end <count> lines`, its count of
  # lines, the header and the end line among them, as `wc -l` counts a file whose last
  # line ends with a newline (the words decision 409's), and since decision 410 however
  # each line ends, LF, CRLF or a lone CR. A store of version 2 whose last line is no end
  # line, or whose end line counts other than the lines it has, is refused at a fresh
  # start, naming the file and the line, so that a store is read whole or not at all. Why
  # a count of lines catches both kinds of cut: a cut keeps a file's first bytes, and the
  # end line, which holds the count, is the last of them. A cut at a line boundary, or
  # inside a line before the end line, a value's number cut in its digits among them,
  # takes the end line with it, and the line that is then last counts nothing; a cut
  # inside the end line cuts its count or the word after it, and a count cut in its digits
  # is smaller than the lines before it and it, which the cut did not change. Only a cut
  # of the last newline alone keeps every line whole, and that store is read. The count
  # catches, too, a line lost or doubled inside the file, and a line a hand edit added or
  # removed without changing it. A store of version 1, which has no end line, is read as
  # it was, a cut one among it; every store written since RV-5 is of version 2, and since
  # RV-26 of version 3, whose end line is version 2's, a cut one refused naming its own
  # header.
  #
  # A store's lines end with LF, as the runner writes them, and since decision 410 (RV-13)
  # a line ended by CRLF or a lone CR is read alike, as B8 has the source's and a
  # configuration file's readers read it, so that a store a hand edit saved with CRLF line
  # ends starts, where RV-5 (a7-docs-1, c2-runner-persist-10) refused it at its first line
  # holding a carriage return; a store saved so and cut short is refused as any cut store
  # is, its last line no end line or its count cut. A refusal names the file and each
  # line, bounded and printable as `Logex.Refusal` has it, the forces file's and the
  # image's too (b3-store-image-11); and a comment, a tab and a byte no store holds are
  # each told as what it is (b3-store-image-10), where a line holding one was told as a
  # line of no shape, or one before any instance's lines, and an empty line after the end
  # line as one, where it would be told as a store cut short. Since RV-5's review a store
  # that begins with a byte-order mark, as an editor that saves UTF-8 with one writes it,
  # is told so in plain words and the rest read as if it were not there; a store cut after
  # its header, inside its second line or at its end, is told once, at the line the cut
  # left last; an end line in a store whose header is not `logex retain 2`, which only
  # version 2's rule reads, and since RV-26 version 3's, is told as one that header does
  # not take, never as one before the store's last, its message naming version 2 alone,
  # since RV-26's review naming versions 3 and 2 in a store of a header this logex does
  # not read, `logex retain 3 ` mistyped among them, and since decision 536 (RV-27) in a
  # store of `logex retain 1` too, one message for every header that takes no end line;
  # and the message for a store cut short said that `start: :cold`
  # writes over it at once, and since decision 417 (RV-13) says that it copies it first,
  # to the next of its numbered copies (decision 418), and then writes over it, as a cold
  # start over any store a fresh start would refuse does (`Logex.Runner`).

  alias Logex.{Array, Declarations, Image, Real, Refusal}

  # Decision 530 (RV-26): the header of a store that names its program, as the runner
  # writes every store; and that of one that names none, as encode/2 writes it and every
  # store was written from decision 355 to RV-26, read as it was.
  @header "logex retain 3"
  @unnamed "logex retain 2"

  # The headers this logex reads, the newest first.
  @headers [@header, @unnamed, "logex retain 1"]

  @reals Declarations.reals()

  # Each elementary type by its word, as a declaration's type word is read.
  @words Map.new(Declarations.elementary(), &{Declarations.word(&1), &1})

  # ---- written ------------------------------------------------------------------------

  # A resource's retained image as the store's text, written at `at`, a UTC DateTime, its
  # last line its count of lines (decision 355), naming no program (a store's text as it
  # was before decision 517), its header `logex retain 2`.
  def encode(image, at), do: encode(image, at, nil)

  # Decision 517 (c), RV-21: and the program that wrote it, `by` (written_by/1), its
  # `resource` line and a `program` line a program type, in name order, after the
  # configuration's line, so that a fresh start can tell a store written by another program
  # than the one it was given (warning/3); since decision 530 (RV-26) under the header
  # `logex retain 3`, so that a logex before it says that it does not read the store's
  # version, where one before RV-21 told a `resource` line as one before any instance's.
  def encode(%{configuration: name, globals: globals, instances: instances} = image, at, by) do
    by = by_lines(by)
    globals = for {name, entry} <- Enum.sort(globals), do: ["global #{name} ", entry(entry), "\n"]
    triggers = for {name, sample} <- Enum.sort(image.triggers), do: "trigger #{name} #{sample}\n"
    instances = for {name, lone} <- Enum.sort(instances), do: instance(name, lone)

    count =
      3 + length(by) + length(globals) + length(triggers) +
        Enum.sum(Enum.map(instances, &length/1))

    IO.iodata_to_binary([
      header_of(by),
      "\n",
      "configuration #{name} written #{DateTime.to_iso8601(at)}\n",
      by,
      globals,
      triggers,
      instances,
      "end #{count} lines\n"
    ])
  end

  defp header_of([]), do: @unnamed
  defp header_of(_by), do: @header

  defp by_lines(nil), do: []

  defp by_lines(%{resource: resource, programs: programs}),
    do: [
      "resource #{resource}\n"
      | for({name, digest} <- Enum.sort(programs), do: "program #{name} #{digest}\n")
    ]

  # Decision 517 (c), RV-21, and decision 527 (RV-26): the program a configuration runs, as
  # a store names it, `%{resource: digest, programs: %{type => digest}}`, each digest the
  # MD5 of a text in 32 lowercase hexadecimal digits. A program type's is of its text and,
  # where it holds user blocks, of each block's name and text after it, in name order, so
  # that a block edited is its holder's text changed too; and since decision 527 each text
  # is the one `Logex.Printer` prints of its parse tree, each literal by its value
  # (canonical/2), as the configuration's own lines are printed before theirs, so that a
  # comment, an empty line, CRLF, spacing or a literal respelt, `16#ff` for `255`, in a
  # name too since RV-26's review, `arr[16#2]` for `arr[2]`, `w.03` for `w.3` and
  # `int[004]` for `int[4]`, in a program's `.ld` or a block's warns of nothing, where
  # the bytes of each file were digested and `md5sum conveyor.ld` gave a type with no
  # blocks; and since decision 532 (RV-27) each word logex reads in any case lowercased,
  # `XIC` for `xic`, `DINT` for `dint` or `FUNCTION_BLOCK` heading a block's file, and a
  # literal bit number in brackets the plain bit, `w.[4]` for `w.4`, so that neither warns,
  # where a tag's name, its case among it, a member's, a label's and a user block's are the
  # text's (cased/2). One with no source
  # text, built by hand, of its rungs and tags as data. The resource's is of the
  # configuration's own lines, its tasks, globals, instances and connections, as
  # `Logex.Configuration.Text.print/1` prints them with no line of their own, so that a
  # comment or an empty line added to the file changes nothing and a task, a global, an
  # instance's type or task, a connection or their order does. The configuration's name is
  # the store's second line already (decision 285). Since RV-21's review its elements
  # are printed as one list, in the order `print/1` gives a configuration of no lines,
  # its tasks, globals, instances and connections, the same text checked once where the
  # configuration's printing checked each part and then the whole; and the runner makes
  # it at a fresh start and, for an edit's candidate, at accept in the caller, never in
  # its own process at a step (`Logex.Runner`'s state).
  def written_by(%Logex.Configuration{programs: programs} = configuration),
    do: %{
      resource: digest(Logex.Configuration.Text.print(unlined(configuration))),
      programs:
        Map.new(programs, fn {name, program} -> {name, digest(texts(program, :canonical))} end)
    }

  # Decisions 530 (RV-26) and 534 (RV-27): the program a store of version 2 or 1 names, as
  # RV-21's logex wrote it, `logex retain 2` with its `resource` and `program` lines, each
  # type's digest the MD5 of its text's bytes, is laid beside the start's program digested
  # so, its configuration's lines as ever, so that a fresh start from such a store warns as
  # RV-21's logex would have, where every type's printed digest would differ from its
  # bytes' and warn of every program once; a store of version 3 names its program printed
  # (written_by/1), which `by` is.
  def compared(%{bytes: true}, by, %Logex.Configuration{programs: programs}),
    do: %{
      by
      | programs:
          Map.new(programs, fn {name, program} -> {name, digest(texts(program, :bytes))} end)
    }

  def compared(_stored, by, _configuration), do: by

  defp unlined(configuration),
    do:
      for(
        part <- [
          configuration.tasks,
          configuration.globals,
          configuration.instances,
          configuration.connections
        ],
        entry <- part,
        do: %{entry | line: nil}
      )

  # Decision 532 (RV-27): a program type's own text, `:program`, and each block's, `:block`,
  # whose first word, `function_block`, is reserved in a block's file alone.
  defp texts(%Logex.Program{source: source, blocks: blocks} = program, form),
    do: [
      own_text(source, program, {form, :program})
      | for(
          {name, %Logex.FbType{body: %Logex.Program{} = body}} <- Enum.sort(blocks),
          do: ["\n", name, "\n", own_text(body.source, body, {form, :block})]
        )
    ]

  defp own_text(source, program, {:canonical, kind}) when is_binary(source),
    do: canonical(source, {kind, program})

  defp own_text(source, _program, {:bytes, _kind}) when is_binary(source), do: source

  defp own_text(nil, program, _form),
    do: :erlang.term_to_binary({program.rungs, program.tags}, [:deterministic])

  # Decision 527 (RV-26): a program's or a block's text as `Logex.Printer` prints its parse
  # tree, one rung a line and one space between its elements, each literal by its value,
  # `255` for `16#ff` and `1.0` for `1.0e0`, and since RV-26's review each number in a
  # name, a subscript, a bit's number or an array's size (by_value/2), and since decision
  # 532 (RV-27) each word logex reads in any case lowercased and a literal bit number in
  # brackets as the plain bit, so that what the lexer skips, a comment, an empty line, a
  # line's end and its spacing, a literal's spelling and what logex reads alike are not
  # the program's; the declarations are rungs to the parser, and printed so too. A text
  # that does not lex or parse, which only a program built by hand holds, every compile's
  # text doing both, is digested as its bytes.
  defp canonical(source, read), do: lexed(Logex.Lexer.tokenize(source), source, read)

  defp lexed({:ok, tokens, _end_line}, source, read),
    do: parsed(Logex.Parser.parse(tokens), source, read)

  defp lexed(_error, source, _read), do: source

  defp parsed({:ok, {:routine, {:rungs, rungs}}}, _source, read),
    do: Logex.Printer.print({:routine, {:rungs, Enum.map(rungs, &by_value(&1, read))}})

  defp parsed(_error, source, _read), do: source

  defp by_value({:rung, elements}, read), do: {:rung, Enum.map(elements, &by_value(&1, read))}

  defp by_value({:branches, legs}, read),
    do: {:branches, Enum.map(legs, &Enum.map(&1, fn e -> by_value(e, read) end))}

  defp by_value({:int_lit, line, value, _spelling}, _read), do: {:int_lit, line, value}
  defp by_value({:real_lit, line, value, _spelling}, _read), do: {:real_lit, line, value}

  # RV-26's review: a number in a name, a subscript, a bit's number or an array's size,
  # by its value too (`Logex.Name.each_by_value/1`), so that `arr[16#2]`, `w.03` and
  # `int[004]` are `arr[2]`, `w.3` and `int[4]`, as the configuration's own lines read
  # `int[16#4]`; since decision 532 (RV-27) a literal bit number in brackets the plain
  # bit, `w.[4]` and `w.[16#4]` both `w.4`, and the name's case read as logex reads it
  # (cased/2).
  defp by_value({:name, line, name}, read),
    do: {:name, line, cased(Logex.Name.each_by_value(name), read)}

  defp by_value(element, _read), do: element

  # Decision 532 (RV-27): each word logex reads in any case lowercased, wherever it stands
  # in the tree, so that `XIC start` for `xic start`, `VAR_INPUT`, `RETAIN`, `DINT`,
  # `TON[4]` for `ton[4]` and, in a block's file, `FUNCTION_BLOCK` change nothing, as the
  # configuration's print lowercases its keywords: a word that `Logex.Declarations.
  # reserved/1` names, a mnemonic, a section, a qualifier, an elementary type's word or a
  # built-in block's type, from the one table that reserves each, whole or as the word
  # before an array's sizes; and in a block's text the word that heads its file
  # (`Logex.Declarations.kinds/0`), which a program's text may hold as a tag's name. Every
  # other name is kept as written, its case its name's: a tag's, a member's, a label's and
  # a user block's, each of which logex reads by its exact name, so that `Start` for
  # `start` is another tag and warns. Only a name holding a capital letter is looked at
  # past one search for one, a program written in lowercase paying that alone; and such a
  # name's word, the whole name or its part before the first `[` or `.`, is looked up
  # first among the tags its text declares, none of which a word logex reserves can be,
  # and kept where it is one, so that a tag in CamelCase, as Logix shops write them,
  # `Eye`, `C7` or `C[7].q`, costs a map's look-up (RV-27's review: each such name
  # looked up in the table, and an element's word read past its subscripts, cost a
  # program of CamelCase tags near a quarter over its texts printed); only a word that is
  # no tag, a keyword, a label or a user block's name, is looked up in the table.
  @capitals for c <- ?A..?Z, do: <<c>>

  defp cased(name, read), do: capital(:binary.match(name, @capitals), name, read)

  defp capital(:nomatch, name, _read), do: name
  defp capital(_found, name, read), do: worded(:binary.match(name, ["[", "."]), name, read)

  defp worded(:nomatch, name, read), do: declared(name, name, read)
  defp worded({at, _length}, name, read), do: declared(binary_part(name, 0, at), name, read)

  defp declared(word, name, {_kind, %{tags: tags}}) when is_map_key(tags, word), do: name

  defp declared(name, name, {kind, _program}),
    do: whole(Declarations.reserved(name), name, kind)

  defp declared(word, name, _read), do: sized(Declarations.reserved(word), byte_size(word), name)

  defp whole(nil, name, :block), do: heading(String.downcase(name) in Declarations.kinds(), name)
  defp whole(nil, name, :program), do: name
  defp whole(_as, name, _kind), do: String.downcase(name)

  defp sized(nil, _at, name), do: name

  defp sized(_as, at, name),
    do: String.downcase(binary_part(name, 0, at)) <> binary_part(name, at, byte_size(name) - at)

  defp heading(true, name), do: String.downcase(name)
  defp heading(false, name), do: name

  defp digest(text), do: Base.encode16(:erlang.md5(text), case: :lower)

  defp instance(name, %{program: program, kinds: kinds, values: values}) do
    lines =
      Image.ordered(
        Enum.map(kinds, fn {path, kind} -> {path, {:kind, kind}} end) ++
          Enum.map(values, fn {path, entry} -> {path, {:value, entry}} end)
      )

    [
      "instance #{name} #{program}\n"
      | for({path, line} <- lines, do: [name, ?., path, ?\s, line_of(line), ?\n])
    ]
  end

  defp line_of({:kind, {:array, kind, dims}}), do: sized(kind, dims)
  defp line_of({:kind, kind}), do: kind
  defp line_of({:value, entry}), do: entry(entry)

  defp entry({{:array, type, dims}, list}),
    do: [
      sized(Declarations.word(type), dims) | Enum.map(List.flatten(list), &[?\s, value(type, &1)])
    ]

  defp entry({type, value}), do: [Declarations.word(type), ?\s, value(type, value)]

  defp sized(word, dims), do: "#{word}[#{Enum.join(dims, ",")}]"

  defp value(type, value) when type in @reals, do: Real.spelled(type, value)
  defp value(_type, value), do: Integer.to_string(value)

  # The time a store is written at, the host's wall clock in ms since the Unix epoch, to
  # the second, as the header holds it.
  def at(wall_ms),
    do: wall_ms |> DateTime.from_unix!(:millisecond) |> DateTime.truncate(:second)

  # The forces file's write rule (decision 127), shared with the store's (decision 275):
  # the text written whole to `<path>.tmp` beside the file, flushed to the disk, closed and
  # renamed over it, so that a crash at any moment leaves the old file or the new; a write
  # that fails leaves the file as it was, `{:error, reason}`, its `.tmp` deleted.
  #
  # Each write's `.tmp` is its own (M10, RV-4), a new file made under the one name,
  # exclusively: where something stands at `<path>.tmp` it is deleted and the file made
  # then, so that a write killed inside a call of the file system, by the runner past its
  # limit or with the runner as it is killed, the write linked to it
  # (`Logex.Runner.Writer`), which runs on to its end in the kernel after the kill, a
  # process killed in a file's call being down at once, and then does nothing more, never
  # reaches this write's file:
  # - a killed write's open, write, sync or close, raw, reaches its own file, which this
  #   write's delete unlinks; an open of its that ends after this one finds this file there
  #   and makes none;
  # - a killed write's rename, which the VM's file server holds in the order asked, has its
  #   file whole and synced at `<path>.tmp`, so this write's open finds it there and its
  #   delete, which goes through that server too, waits for the rename, the store then that
  #   write, whole, and the `.tmp` free.
  # So the store is the old or the new, never a mix, and a write killed in its rename
  # may still land once the disk answers. A FIFO, a link or a leftover at `<path>.tmp` is
  # removed, never written through; a directory there cannot be, and the write fails,
  # `:eisdir`. Only the rename, and a delete where something stands, go through the file
  # server, whose queue every other process's file calls share; the rest is raw.
  # (Decision 392: one name, its file new each write, where the review suggested a unique
  # name a write, which would leave each killed write's file beside the store and change
  # the name decision 325 and the documents give.)
  def written(path, text) when is_binary(path) do
    beside = path <> ".tmp"
    renamed(written_out(made(beside), text), beside, path)
  end

  # Decision 418 (RV-13): a copy of the store, `{path, beside}`, its name of its own,
  # `<store>.dropped.<n>`, written through the one `.tmp` every copy of the store is
  # written through, `<store>.dropped.tmp` (decision 392's one `.tmp`, unchanged), by the
  # same rule, and not renamed over a file that stands at its name as it looks: where
  # anything stands there, looked at raw once the `.tmp` is written, just before the
  # rename, which its number, one past the highest that stands
  # (`Logex.Runner.Writer.copy/3`), leaves only to a file made there since the directory
  # was read, the write fails, `{:error, :eexist}`, its `.tmp` deleted, the file that
  # stands untouched. The look and the rename are two calls, the rename through the VM's
  # file server, whose queue on a stalled disk it waits in: a file a host makes at the
  # copy's name between them is replaced by the copy (decision 449, as built: a rename
  # that refuses a name that stands is a hard link, which a FAT card has not); one made
  # before the look fails the copy, owed (decision 448).
  def written({path, beside}, text),
    do: unreplaced(written_out(made(beside), text), beside, path)

  defp unreplaced(:ok, beside, path),
    do: free(:file.read_link_info(path, [:raw]), beside, path)

  defp unreplaced(error, beside, _path), do: discarded(error, beside)

  defp free({:error, :enoent}, beside, path), do: renamed(:ok, beside, path)
  defp free({:ok, _info}, beside, _path), do: discarded({:error, :eexist}, beside)
  defp free(error, beside, _path), do: discarded(error, beside)

  defp made(beside), do: made_again(made_new(beside), beside)

  defp made_new(beside), do: :file.open(beside, [:write, :exclusive, :raw, :binary])

  defp made_again({:error, :eexist}, beside) do
    _ = :file.delete(beside)
    standing(made_new(beside), beside)
  end

  defp made_again(opened, _beside), do: opened

  # What stands at the `.tmp` and cannot be deleted: a directory, `:eisdir`, as an open
  # of it says, or anything else, `:eexist`.
  defp standing({:error, :eexist}, beside),
    do: {:error, kind_of(:file.read_link_info(beside, [:raw]))}

  defp standing(opened, _beside), do: opened

  defp kind_of({:ok, info}) when elem(info, 2) == :directory, do: :eisdir
  defp kind_of(_other), do: :eexist

  defp written_out({:ok, io}, text), do: synced(:file.write(io, text), io)
  defp written_out(error, _text), do: error

  defp synced(:ok, io), do: closed(:file.sync(io), io)
  defp synced(error, io), do: closed(error, io)

  defp closed(:ok, io), do: :file.close(io)

  defp closed(error, io) do
    :file.close(io)
    error
  end

  defp renamed(:ok, beside, path), do: discarded(:file.rename(beside, path), beside)
  defp renamed(error, beside, _path), do: discarded(error, beside)

  defp discarded(:ok, _beside), do: :ok

  defp discarded(error, beside) do
    :file.delete(beside)
    error
  end

  # ---- read ---------------------------------------------------------------------------

  # A store's text read back, `{image, written_at}`, for the configuration `name`; one that
  # is not one, or is of another configuration, is the host's mistake, every problem a line
  # of one ArgumentError, `<path>: line <n>: …` (decisions 276 and 285). What its image
  # holds is judged by `Logex.Runtime.start/2`, which forgives a changed configuration.
  def decode!(text, named) do
    {image, written_at, _by} = decoded!(text, named)
    {image, written_at}
  end

  # Decision 517 (c), RV-21: the same, and the program the store names as its writer, as
  # written_by/1 gives one, nil for a store that names none, one written before RV-21 among
  # them, which is read as it was and warns of nothing.
  def decoded!(text, {path, name}) do
    {marked, lines} = text |> lines() |> unended() |> Enum.with_index(1) |> marked()
    {written_at, problems} = headed(lines, name)
    {body, ending, last} = ended(lines)

    acc = %{
      image: empty(name),
      by: nil,
      instance: nil,
      seen: %{},
      problems: Enum.reverse(marked ++ before_end(problems, last)),
      unprintable: Refusal.pattern(),
      ended: last != nil,
      unread_by: %{}
    }

    acc =
      body |> Enum.drop(2) |> Enum.reduce(acc, &line/2) |> resourced() |> naming(lines, ending)

    refused!(Enum.sort_by(Enum.reverse(acc.problems), &elem(&1, 0)) ++ ending, path)
    {acc.image, written_at, versioned(acc.by, lines)}
  end

  # Decision 535 (RV-27): a store of `logex retain 3` is one that names the program that
  # wrote it, as every store the runner writes since decision 530 does, so one that names
  # none, its `resource` and `program` lines a hand edit took away, is refused, located at
  # its header, the line that says it names one (provisional, `PLAN.md`'s RV-27), as
  # decision 531 refuses one that names it in part at its first `program` line, where it
  # was read as naming none; a cold start copies it first, as any refused store
  # (decision 417). A store whose end line does not read, cut short or miscounted, is told
  # that alone (decision 355), since a cut before the configuration's line's end takes the
  # lines that name its program with it (provisional, `PLAN.md`'s RV-27). A store of
  # `logex retain 2` or `logex retain 1` that names none is read as it was, one relabelled
  # so by hand among them. One of `logex retain 3` that names its resource and no program
  # type, which no configuration gives, each declaring a program, is read, and a warm start
  # from it warns that each type it runs is not in the store (provisional, `PLAN.md`'s
  # RV-27, question 3); and one whose `resource` or `program` line does not read is told
  # that line, and not that it names none (unread_by/2).
  defp naming(%{by: nil, unread_by: unread} = acc, [{@header, 1} | _rest], [])
       when map_size(unread) == 0,
       do:
         problem(
           acc,
           1,
           "`#{@header}` heads a store that names the program that wrote it, and the store " <>
             "names none: a store that names the program that wrote it gives `resource " <>
             "<digest>` straight after its configuration's line, and then a `program <type> " <>
             "<digest>` a type"
         )

  defp naming(acc, _lines, _ending), do: acc

  # Decision 530 (RV-26): the program a store names, as a store of version 3 names it,
  # printed; one of version 2 or 1 that names one, as RV-21's logex wrote it, marked as
  # digested by its bytes (compared/3).
  defp versioned(nil, _lines), do: nil
  defp versioned(by, [{@header, 1} | _rest]), do: by
  defp versioned(by, _lines), do: Map.put(by, :bytes, true)

  # Decision 517 (c), RV-21, and decision 527 (RV-26): what a warm fresh start warns of,
  # nil where the store names no program, written before RV-21, or the very program the
  # start was given; otherwise one message, naming the start's store as the host spelled
  # it, the configuration's own lines where their digest differs and each program type
  # whose digest differs, is only the store's or only the start's, in name order, the
  # first ten and then a count, and since decision 527 both causes, a deploy of changed
  # files, or an edit tested or assembled online, which lives in the runner and the store,
  # that never reached the files the start was given, where it named the edit alone. It
  # changes nothing else: the image is laid over the start's configuration by name and type
  # as decision 277 has it.
  def warning(nil, _by, _path), do: nil

  def warning(stored, by, path),
    do:
      told(
        resource_differs(stored.resource == by.resource) ++
          Enum.flat_map(
            Enum.sort(Enum.uniq(Map.keys(stored.programs) ++ Map.keys(by.programs))),
            &program_differs(Map.get(stored.programs, &1), Map.get(by.programs, &1), &1)
          ),
        path
      )

  defp resource_differs(true), do: []

  defp resource_differs(false),
    do: ["the configuration's tasks, globals, instances or connections differ"]

  defp program_differs(same, same, _name), do: []
  defp program_differs(nil, _digest, name), do: ["`#{name}` is not in the store"]
  defp program_differs(_digest, nil, name), do: ["`#{name}` is not in this start"]
  defp program_differs(_stored, _digest, name), do: ["`#{name}`'s text differs"]

  defp told([], _path), do: nil

  defp told(differences, path),
    do:
      "#{Refusal.path(path)}: the store was written by another program than the one this " <>
        "start was given: " <>
        Enum.join(Array.capped(differences, &"and #{&1} more"), ", ") <>
        "; whether by a deploy of changed files, or an edit tested or assembled online that " <>
        "never reached the files, this start runs the program it was given, with the " <>
        "store's retained values laid over it by name and type"

  # RV-5's review: a store that begins with a byte-order mark, as an editor that saves
  # UTF-8 with one writes it, told so in plain words at its first line, and the rest of
  # the store read as if the mark were not there, so that its header and its end line are
  # each judged as they are, where the header was told as no store's and its true end
  # line as one before the store's last.
  defp marked([{<<0xEF, 0xBB, 0xBF, first::binary>>, 1} | rest]),
    do:
      {[
         {1,
          "the store begins with a byte-order mark, `\\xEF\\xBB\\xBF`, as an editor that saves " <>
            "UTF-8 with one writes it: a store is ASCII and begins `#{begun(first)}`, so save it " <>
            "without one"}
       ], [{first, 1} | rest]}

  defp marked(lines), do: {[], lines}

  # Decision 530 (RV-26): the header a store begins with where it is one this logex reads,
  # and otherwise the one it writes.
  defp begun(first) when first in @headers, do: first
  defp begun(_first), do: @header

  # RV-5's review: the header's problems at the line judged as the store's end line, or
  # after it, which only a store cut inside its first two lines has, not told, that line
  # told once as the store's last and every problem in line order, where a cut inside the
  # second line told it twice and a cut after the first told the second before it.
  defp before_end(problems, nil), do: problems
  defp before_end(problems, last), do: for({n, _} = problem <- problems, n < last, do: problem)

  # Decision 355: a store of version 2 ends with its end line, `end <count> lines`, the
  # count every line it has, the header and the end line among them; its lines before it
  # are the store's, and a last line that is no end line, or whose count is not the
  # store's, is a problem of its line, the store refused whole, so that a store cut short
  # anywhere is never read short (see the head of this module). The last line of such a
  # store is judged as its end line alone, so that a line a cut left half is told once,
  # its number given back, nil for a store judged by version 1's rule. A store of version
  # 1 has no end line and is read as it was.
  defp ended([{header, 1} | _rest] = lines) when header in [@header, @unnamed],
    do: trailing(Enum.reverse(lines), [], header)

  defp ended(lines), do: {lines, [], nil}

  # RV-5 (b3-store-image-10): an empty line after the last a store holds, which a hand
  # edit's editor may leave, told as what it is, the line before it judged as the end
  # line, where it was told as a store cut short.
  defp trailing([{"", n} | rest], empty, header) when rest != [],
    do: trailing(rest, [n | empty], header)

  defp trailing(reversed, empty, header), do: end_line(Enum.reverse(reversed), empty, header)

  defp end_line(lines, empty, header) do
    {text, n} = List.last(lines)

    {Enum.drop(lines, -1), ending(String.split(text, " "), text, n, header) ++ after_end(empty),
     n}
  end

  defp after_end(empty),
    do: for(n <- empty, do: {n, "an empty line, which a store never holds: its end line is last"})

  defp ending(["end", count, "lines"], text, n, _header), do: counted(number(count), text, n)

  # Decision 417 (RV-13): the remedy says that a cold start copies the store first, under
  # the next of its numbered copies (decision 418), and then writes over it, where it
  # warned the operator to copy it aside first; since decision 530 (RV-26) naming the
  # store's own header, `logex retain 3` or `logex retain 2`.
  defp ending(_other, text, n, header),
    do: [
      {n,
       "#{quoted(text)} is the store's last line, and no end line: a store of " <>
         "`#{header}` ends with `end <count> lines`, its count of lines, so this one was " <>
         "cut short, and a store cut short is not read: start it with start: :cold to " <>
         "start over it, which copies it first to the next `.dropped.<n>` beside it and " <>
         "then writes a new store over it"}
    ]

  defp counted({:ok, n}, _text, n), do: []

  defp counted({:ok, count}, _text, n) when is_integer(count) and count >= 0,
    do: [
      {n,
       "the store's end line counts #{count} lines, and the store has #{n}: a line was " <>
         "lost or doubled, or a hand edit added or removed one without changing the count, " <>
         "which counts every line, the end line among them, and the store is not read"}
    ]

  defp counted(_other, text, n),
    do: [
      {n,
       "#{quoted(text)} counts no lines: a store's end line is `end <count> lines`, its " <>
         "count of lines a whole number"}
    ]

  # Decision 410 (RV-13): a store's lines end with LF, CRLF or a lone CR alike, as B8 has
  # the source's and a configuration file's readers read them (`Logex.Lexer`,
  # `Logex.Configuration.Text`), so that a store a hand edit saved with CRLF line ends,
  # or a lone CR's, is read as the store it is, where since RV-5 it was refused at its
  # first line holding a carriage return; the runner writes LF. `\r\n` is one line end,
  # the longest of the three where they meet, and `\r\r\n` two, a line left empty between
  # them, as the lexer reads it.
  defp lines(text), do: String.split(text, ["\r\n", "\r", "\n"])

  # The text after the last line end, empty in a file the runner wrote, is no line.
  defp unended(lines), do: unended(List.last(lines), lines)
  defp unended("", lines), do: Enum.drop(lines, -1)
  defp unended(_last, lines), do: lines

  defp empty(name), do: %{configuration: name, globals: %{}, instances: %{}, triggers: %{}}

  defp refused!([], _path), do: :ok
  defp refused!(problems, path), do: raise(ArgumentError, Refusal.of(problems, path))

  defp quoted(text), do: Refusal.quoted(text)

  # The header, its version, and the configuration and the time, each a problem of its
  # line where it is not one.
  defp headed([], _name),
    do: {nil, [{1, "the store is empty: its first line is `#{@header}`"}]}

  defp headed([{first, 1} | rest], name),
    do: {written_at(rest), header(String.split(first, " "), first) ++ named(rest, name)}

  defp header(["logex", "retain", version], _text) when version in ["1", "2", "3"], do: []

  # Decision 530 (RV-26): a version past 3 told plainly, as a logex before RV-26 tells a
  # store of version 3.
  defp header(["logex", "retain", version], _text),
    do: [
      {1,
       "the store is of version #{Refusal.shown(version)}, which this logex does not " <>
         "read: it reads `#{@header}`, `#{@unnamed}` and `logex retain 1`"}
    ]

  defp header(_other, text),
    do: [{1, "#{quoted(text)} is no store's header: a store's first line is `#{@header}`"}]

  defp named([], _name),
    do: [
      {2,
       "the store names no configuration: its second line is `configuration <name> " <>
         "written <time>`"}
    ]

  defp named([{text, 2} | _rest], name),
    do: configuration(String.split(text, " "), text, name)

  defp configuration(["configuration", name, "written", time], _text, name), do: time_lines(time)

  defp configuration(["configuration", stored, "written", time], _text, name),
    do:
      [
        {2,
         "the store is of configuration #{quoted(stored)}, and this configuration is " <>
           "`#{name}`: " <>
           "a store starts only the configuration it was written for, so a renamed " <>
           "configuration starts only cold: start it with start: :cold to start over it"}
      ] ++ time_lines(time)

  defp configuration(_other, text, _name),
    do: [
      {2,
       "#{quoted(text)} names no configuration: a store's second line is `configuration " <>
         "<name> written <time>`"}
    ]

  defp time_lines(time), do: time_problem(DateTime.from_iso8601(time), time)

  defp time_problem({:ok, _at, 0}, _time), do: []

  defp time_problem(_other, time),
    do: [
      {2, "#{quoted(time)} is no time a store is written at, in UTC, as 2026-10-27T14:00:00Z"}
    ]

  defp written_at([{text, 2} | _rest]), do: at_of(String.split(text, " "))
  defp written_at(_none), do: nil

  defp at_of(["configuration", _name, "written", time]), do: utc(DateTime.from_iso8601(time))
  defp at_of(_other), do: nil

  defp utc({:ok, at, 0}), do: at
  defp utc(_other), do: nil

  # Each line after the header: a global, a trigger, an instance, or one of the instance's
  # lines, a kind or a value. Since RV-5 (b3-store-image-10) a comment, `//` or `#`, a tab
  # and a byte no store holds are each told as what they are, where a line holding one
  # was told as a line of no shape, or as one that comes before any instance's lines.
  defp line({<<"//", _::binary>> = text, n}, acc), do: problem(acc, n, commented(text))
  defp line({<<"#", _::binary>> = text, n}, acc), do: problem(acc, n, commented(text))

  defp line({text, _n} = at, acc),
    do: printable(Refusal.unprintable(text, acc.unprintable), at, acc)

  defp printable(:nomatch, {text, _n} = at, acc), do: spaced(String.split(text, " "), at, acc)

  defp printable({byte, 1}, {text, n}, acc),
    do: problem(acc, n, unprintable(:binary.at(text, byte), text))

  defp commented(text),
    do:
      "#{quoted(text)} is a comment, and a store holds none: the runner writes the store " <>
        "whole at every write, so no comment outlives the next"

  defp unprintable(?\t, text),
    do: "#{quoted(text)} holds a tab, and a store's words are each one space apart"

  defp unprintable(byte, text),
    do:
      "#{quoted(text)} holds the byte #{Refusal.escaped(byte)}, which no store holds: a " <>
        "store's text " <>
        "is printable ASCII, its words each one space apart"

  # A line's words each one space apart, with none before or after: any other spacing is
  # no line.
  defp spaced(words, at, acc), do: shaped("" in words, words, at, acc)

  defp shaped(true, _words, at, acc), do: line([], at, acc)
  defp shaped(false, words, at, acc), do: line(words, at, acc)

  defp line(["global", name, type | values], at, acc) when values != [],
    do: entered(typed(type, values), {:global, name}, at, acc)

  defp line(["trigger", name, sample], at, acc),
    do: entered(sample(number(sample), sample), {:trigger, name}, at, acc)

  defp line(["instance", name, program], at, acc), do: instance(name, program, at, acc)

  # Decision 517 (c), RV-21: the program that wrote the store, its resource's digest and a
  # program type's, each once, each digest 32 lowercase hexadecimal digits, as encode/3
  # writes it; a word that is no path, having no `.`, so that no instance's line is one.
  # Each is read wherever it stands, as a global's and a trigger's line are, a line's kind
  # its first word; and a type's name is any name, as an `instance` line's is, `ton` and
  # `end` naming types a configuration may hold. Since RV-21's review a store that
  # names a program type names its resource too (resourced/1), so that a store whose
  # `resource` line a hand edit took away is refused, where it was read and warned that the
  # configuration's lines differed, which nothing said.
  defp line(["resource", digest], at, acc), do: by_entered(digested(digest), :resource, at, acc)

  defp line(["program", name, digest], {_text, n} = at, acc),
    do:
      by_entered(
        digested(digest),
        {:program, name},
        at,
        named_problem(acc, name, n, "program type")
      )

  defp line(["resource" | _words], {text, n}, acc),
    do:
      problem(
        unread_by(acc, :resource),
        n,
        "#{quoted(text)} is no resource's line: it is `resource <digest>`"
      )

  defp line(["program" | _words], {text, n}, acc),
    do:
      problem(
        unread_by(acc, :program),
        n,
        "#{quoted(text)} is no program's line: it is `program <type> <digest>`"
      )

  # Decision 355: an end line anywhere but last, which no path is, having no `.`; and since
  # RV-5's review one in a store not judged by version 2's rule, its header not `logex
  # retain 2`, told so, where its last line was told as one before the store's last.
  defp line(["end", _count, "lines"], {text, n}, %{ended: true} = acc),
    do:
      problem(
        acc,
        n,
        "#{quoted(text)} comes before the store's last line: a store's end line is its last " <>
          "line"
      )

  # RV-26's review and decision 536 (RV-27): in a store whose first line takes no end
  # line, a header this logex does not read or `logex retain 1`, an end line is told as one
  # of either header that takes one, `logex retain 3`, which the runner writes since
  # decision 530, or `logex retain 2`, which it wrote before, one message for every such
  # header, where it named version 2 alone, so that a hand edit of a version 3 store, its
  # header mistyped or made `logex retain 1`, is not pointed at version 2's, which would
  # read its digests as RV-21's and warn that its text differs though nothing does.
  defp line(["end", _count, "lines"], {text, n}, acc),
    do:
      problem(
        acc,
        n,
        "#{quoted(text)} is an end line, which a store whose first line is `#{@header}` or " <>
          "`#{@unnamed}` ends with, and this store's first line is neither"
      )

  defp line([path, kind], at, acc), do: under(acc.instance, path, {:kind, kind}, at, acc)

  defp line([path, type | values], at, acc) when values != [],
    do: under(acc.instance, path, {:value, type, values}, at, acc)

  defp line(_other, {text, n}, acc),
    do:
      problem(
        acc,
        n,
        "#{quoted(text)} is no line of a store: a line is `global <name> <type> <value>`, " <>
          "`trigger <name> <sample>`, `resource <digest>`, `program <type> <digest>`, " <>
          "`instance <name> <program type>`, `<path> <kind>` or `<path> <type> <value>`"
      )

  defp problem(acc, n, message), do: %{acc | problems: [{n, message} | acc.problems]}

  # RV-21's review: a store that names its writer's program types names its resource
  # too, a problem of the first `program` line where it does not, as the reader read it.
  # The line is the three words the reader took it as, each one space apart.
  defp resourced(%{by: %{resource: nil}, unread_by: %{resource: true}} = acc), do: acc

  defp resourced(%{by: %{resource: nil, programs: programs}} = acc) do
    {name, n} = Enum.min_by(for({{:program, name}, n} <- acc.seen, do: {name, n}), &elem(&1, 1))

    problem(
      acc,
      n,
      "#{quoted("program #{name} #{Map.fetch!(programs, name)}")} names a program type of " <>
        "the store's writer, and the store names no resource: a store that names the " <>
        "program that wrote it gives `resource <digest>` straight after its configuration's " <>
        "line, and then a `program <type> <digest>` a type"
    )
  end

  defp resourced(acc), do: acc

  defp instance(name, program, {_text, n} = at, acc) do
    acc =
      %{acc | instance: name}
      |> named_problem(name, n, "instance")
      |> named_problem(program, n, "program type")

    once(acc, {:instance, name}, at, fn acc ->
      lone = %{program: program, kinds: %{}, values: %{}}
      %{acc | image: %{acc.image | instances: Map.put(acc.image.instances, name, lone)}}
    end)
  end

  defp named_problem(acc, name, n, what),
    do: name_problem(Declarations.name?(name), name, n, what, acc)

  defp name_problem(true, _name, _n, _what, acc), do: acc

  defp name_problem(false, name, n, what, acc),
    do: problem(acc, n, "#{quoted(name)} names no #{what}")

  defp under(nil, _path, _line, {text, n}, acc),
    do:
      problem(
        acc,
        n,
        "#{quoted(text)} comes before any `instance` line: an instance's lines follow its own"
      )

  defp under(name, path, line, at, acc),
    do: inside(String.split(path, name <> ".", parts: 2), name, line, at, acc)

  defp inside(["", inner], name, line, at, acc) when inner != "",
    do: put(read_line(line), name, inner, at, acc)

  defp inside(_other, name, _line, {text, n}, acc),
    do:
      problem(
        acc,
        n,
        "#{quoted(text)} is not under the instance #{quoted(name)} whose lines it follows"
      )

  defp read_line({:kind, kind}), do: kind(sized_word(kind), kind)
  defp read_line({:value, type, values}), do: typed(type, values)

  # A kind: a built-in's or a block's name, or an array of its instances, `ton[4]`.
  defp kind(nil, kind), do: kind_named(Declarations.name?(kind), kind, kind)

  defp kind({name, sizes}, kind),
    do: kind_named(Declarations.name?(name), {:array, name, sizes}, kind)

  defp kind(:error, kind), do: {:error, no_kind(kind)}

  defp kind_named(true, kind, _text), do: {:ok, {:kind, kind}}
  defp kind_named(false, _kind, text), do: {:error, no_kind(text)}

  defp no_kind(kind),
    do:
      "#{quoted(kind)} is no kind of instance: a built-in's or a block's name, or an array of " <>
        "its instances, as `ton[4]`"

  # A word with sizes, `int[8]` or `ton[2,3]`, as a store's text spells one: a word, one
  # `[`, the sizes split by `,` and the `]` that ends the word, `{word, sizes}`, each size a
  # whole number above 0 that `number/1` reads, an array's 1 to 3 of them and 65,536
  # elements at most (decision 151); nil where the word holds no `[`; and `:error` where its
  # brackets or its sizes are no array's, `real[]]`, `int[2#]`, `int[3a]` or `int[0]`, which
  # only a hand edit writes (decision 284), so that every such line is refused in its own
  # words and none reaches a reader that takes the lexer's word for the text.
  defp sized_word(word), do: sized_parts(:binary.split(word, "["))

  defp sized_parts([_word]), do: nil
  defp sized_parts([base, rest]), do: bracket_closed(:binary.split(rest, "]"), base)

  defp bracket_closed([inner, ""], base),
    do: bounded(sizes(:binary.split(inner, ",", [:global])), base)

  defp bracket_closed(_other, _base), do: :error

  defp bounded(:error, _base), do: :error

  defp bounded(sizes, base),
    do:
      bounded_at(
        length(sizes) <= Array.max_dimensions() and Array.size(sizes) <= Array.max_elements(),
        sizes,
        base
      )

  defp bounded_at(true, sizes, base), do: {base, sizes}
  defp bounded_at(false, _sizes, _base), do: :error

  defp sizes(texts), do: Enum.reduce_while(texts, [], &size/2) |> sized_list()

  defp size(text, acc), do: size_of(number(text), acc)

  defp size_of({:ok, n}, acc) when is_integer(n) and n > 0, do: {:cont, [n | acc]}
  defp size_of(_other, _acc), do: {:halt, :error}

  defp sized_list(:error), do: :error
  defp sized_list(sizes), do: Enum.reverse(sizes)

  # A type word, an elementary type's or an array's, `int[8]`, and its values, one each
  # element, each a number the lexer reads as one literal.
  defp typed(word, values), do: values_of(type(word), values, word)

  defp type(word), do: type_of(Map.fetch(@words, String.downcase(word)), word)

  defp type_of({:ok, type}, _word), do: {:ok, type}
  defp type_of(:error, word), do: array_type(sized_word(word))

  defp array_type({base, dims}), do: element_type(Map.fetch(@words, String.downcase(base)), dims)
  defp array_type(_none), do: :error

  defp element_type({:ok, type}, dims), do: {:ok, {:array, type, dims}}
  defp element_type(:error, _dims), do: :error

  defp values_of(:error, _values, word),
    do:
      {:error,
       "#{quoted(word)} is no type of a retained value: an elementary type's word, or an array " <>
         "of one, as `int[8]`"}

  defp values_of({:ok, {:array, type, dims} = whole}, values, word),
    do: counted(length(values) == Array.size(dims), whole, numbers(values, type), word)

  defp values_of({:ok, type}, [value], _word), do: one(number(value), type, value)

  defp values_of({:ok, _type}, values, word),
    do: {:error, "#{quoted(word)} holds one value, and the line gives #{length(values)}"}

  defp counted(true, {:array, _type, dims} = whole, {:ok, values}, _word),
    do: {:ok, {:value, {whole, Array.to_list(Array.from_flat(values, dims), dims)}}}

  defp counted(true, _whole, {:error, text}, _word), do: {:error, no_number(text)}

  defp counted(false, {:array, _type, dims}, _values, word),
    do:
      {:error,
       "#{quoted(word)} holds #{Array.size(dims)} values, one an element, in the elements' " <>
         "order"}

  defp numbers(values, type),
    do: Enum.reduce_while(values, {:ok, []}, &each_number(&1, &2, type)) |> reversed()

  defp each_number(text, {:ok, acc}, type), do: next_number(number(text), text, acc, type)

  defp next_number({:ok, n}, _text, acc, type), do: {:cont, {:ok, [held(type, n) | acc]}}
  defp next_number(:error, text, _acc, _type), do: {:halt, {:error, text}}

  defp reversed({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reversed(error), do: error

  defp sample({:ok, n}, _text), do: {:ok, n}
  defp sample(:error, text), do: {:error, no_number(text)}

  defp one({:ok, n}, type, _text), do: {:ok, {:value, {type, held(type, n)}}}
  defp one(:error, _type, text), do: {:error, no_number(text)}

  defp no_number(text), do: "#{quoted(text)} is no number"

  # A real's text read as its type's nearest value, as a forces file's is (decision 156),
  # so that the shortest text of a single reads back to the single; one past its range
  # kept as read, which the start drops as a misfit.
  defp held(type, n) when type in @reals and is_float(n),
    do: held_real(Real.in_range?(type, n), type, n)

  defp held(_type, n), do: n

  defp held_real(true, type, n), do: Real.nearest(type, n)
  defp held_real(false, _type, n), do: n

  # A global's or a trigger's entry, once, its name a name.
  defp entered({:error, message}, _key, {_text, n}, acc), do: problem(acc, n, message)

  defp entered({:ok, entry}, {kind, name} = key, {_text, n} = at, acc) do
    acc = named_problem(acc, name, n, "global")
    once(acc, key, at, &put_entry(kind, name, entry, &1))
  end

  # Decision 517 (c), RV-21: a digest, as encode/3 writes one.
  defp digested(digest) when byte_size(digest) == 32,
    do: hex(Base.decode16(digest, case: :lower), digest)

  defp digested(digest), do: no_digest(digest)

  defp hex({:ok, _bytes}, digest), do: {:ok, digest}
  defp hex(:error, digest), do: no_digest(digest)

  defp no_digest(digest),
    do: {:error, "#{quoted(digest)} is no digest: a store's is 32 lowercase hexadecimal digits"}

  defp by_entered({:error, message}, key, {_text, n}, acc),
    do: problem(unread_by(acc, by_kind(key)), n, message)

  defp by_entered({:ok, digest}, key, at, acc),
    do: once(acc, key, at, &%{&1 | by: put_by(key, digest, by_of(&1.by))})

  # RV-27's review: a `resource` or `program` line that does not read, its digest none or
  # its words not the line's, told as itself, and the store not told also that it names
  # no resource (resourced/1) or none (naming/3), which it may name once that line is
  # mended: decision 535 refuses a store with neither line, and decision 531 one that names
  # a type and no resource, where such a line is one.
  defp unread_by(acc, kind), do: %{acc | unread_by: Map.put(acc.unread_by, kind, true)}

  defp by_kind({:program, _name}), do: :program
  defp by_kind(:resource), do: :resource

  defp by_of(nil), do: %{resource: nil, programs: %{}}
  defp by_of(by), do: by

  defp put_by(:resource, digest, by), do: %{by | resource: digest}

  defp put_by({:program, name}, digest, by),
    do: %{by | programs: Map.put(by.programs, name, digest)}

  defp put_entry(:global, name, {:value, entry}, acc),
    do: %{acc | image: %{acc.image | globals: Map.put(acc.image.globals, name, entry)}}

  defp put_entry(:trigger, name, sample, acc),
    do: %{acc | image: %{acc.image | triggers: Map.put(acc.image.triggers, name, sample)}}

  defp put({:error, message}, _name, _inner, {_text, n}, acc), do: problem(acc, n, message)

  defp put({:ok, line}, name, inner, at, acc),
    do:
      once(acc, {name, inner}, at, fn acc ->
        lone = put_lone(line, inner, Map.fetch!(acc.image.instances, name))
        %{acc | image: %{acc.image | instances: Map.put(acc.image.instances, name, lone)}}
      end)

  defp put_lone({:kind, kind}, inner, lone), do: %{lone | kinds: Map.put(lone.kinds, inner, kind)}

  defp put_lone({:value, entry}, inner, lone),
    do: %{lone | values: Map.put(lone.values, inner, entry)}

  # What a line names, once: a second line naming it is a problem of its own, the first
  # line kept.
  defp once(acc, key, {text, n}, put),
    do: once_at(Map.fetch(acc.seen, key), key, {text, n}, acc, put)

  defp once_at({:ok, first}, _key, {text, n}, acc, _put),
    do: problem(acc, n, "#{quoted(text)} names what line #{first} names already")

  defp once_at(:error, key, {_text, n}, acc, put),
    do: put.(%{acc | seen: Map.put(acc.seen, key, n)})

  # A number's text, any number the lexer reads as one literal, decision 149's forms
  # among them, `37.50`, `3.75e1`, `16#ff` or `1_000`, and nothing else, so that a comment
  # or a tab the lexer would pass over, `1//c` or `1\t`, is none: the forces file's rule
  # (decisions 218 and 226), shared with the store's.
  def number(text), do: valued(number_text?(text), Logex.Lexer.tokenize(text))

  defp number_text?(<<c, rest::binary>>)
       when c in ?0..?9 or c in ?a..?z or c in ?A..?Z or c in [?-, ?#, ?_, ?.],
       do: number_text?(rest)

  defp number_text?(<<>>), do: true
  defp number_text?(_other), do: false

  defp valued(false, _tokens), do: :error

  defp valued(true, {:ok, [{kind, _at, number}], _end_line}) when kind in [:int_lit, :real_lit],
    do: {:ok, number}

  # Since decision 228 a subnormal double, `1.0e-310`, lexes as itself; and since decision
  # 231 one no float holds, `1.0e-400`, lexes as 0.0 with its spelling.
  defp valued(true, {:ok, [{kind, _at, number, _spelling}], _end_line})
       when kind in [:int_lit, :real_lit],
       do: {:ok, number}

  defp valued(true, _other), do: :error
end
