#!/usr/bin/env ruby
require File.expand_path("../../helper", __FILE__)

# Test of Debugger.debug_load in C extension ruby_debug.so
class TestDebugLoad < Test::Unit::TestCase
  class << self
    def at_line(file, line)
      @@at_line = [File.basename(file), line]
    end
  end

  class Debugger::Context
    def at_line(file, line)
      TestDebugLoad::at_line(file, line)
    end
  end

  def test_debug_load
    src_dir = File.dirname(__FILE__)
    prog_script = File.join(src_dir, '..', 'example', 'gcd.rb')

    # Without stopping
    bt = Debugger.debug_load(prog_script, false)
    assert_equal(nil, bt)

    # With stopping
    bt = Debugger.debug_load(prog_script, true)
    assert_equal(nil, bt)
    assert_equal(['gcd.rb', 4], @@at_line)

    # Test that we get a proper backtrace on a script that raises 'abc'
    prog_script = File.join(src_dir, '..', 'example', 'raise.rb')
    bt = Debugger.debug_load(prog_script, false)
    assert_equal('abc', bt.to_s)
  ensure
    Debugger.stop
  end
end
