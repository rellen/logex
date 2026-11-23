ExUnit.start(autorun: false, formatters: [])
Code.require_file("test/packing_test.exs")
%{total: total, failures: failures} = ExUnit.run()
IO.puts("#{total} tests, #{failures} failures")
