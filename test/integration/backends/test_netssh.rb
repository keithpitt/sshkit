require 'helper'

module SSHKit

  module Backend

    class ToSIoFormatter < StringIO
      extend Forwardable
      attr_reader :original_output
      def_delegators :@original_output, :read, :rewind
      def initialize(oio)
        @original_output = oio
      end
      def write(obj)
        warn "What: #{obj.to_hash}"
        original_output.write "> Executing #{obj}\n"
      end
    end

    class TestPrinter < FunctionalTest

      def block_to_run
        lambda do |host|
          execute 'date'
          execute :ls, '-l', '/some/directory'
          with rails_env: :production do
            within '/tmp' do
              as :root do
                execute :touch, 'restart.txt'
              end
            end
          end
        end
      end

      def a_host
        vm_hosts.first
      end

      def printer
        Netssh.new(a_host, &block_to_run)
      end

      def simple_netssh
        sio = ToSIoFormatter.new(StringIO.new)
        Deploy.capture_output(sio) do
          printer.run
        end
        sio.rewind
        result = sio.read
        assert_equal <<-EOEXPECTED.unindent, result
          > Executing if test ! -d /opt/sites/example.com; then echo "Directory does not exist '/opt/sites/example.com'" 2>&1; false; fi
          > Executing cd /opt/sites/example.com && /usr/bin/env date
          > Executing cd /opt/sites/example.com && /usr/bin/env ls -l /some/directory
          > Executing if test ! -d /opt/sites/example.com/tmp; then echo "Directory does not exist '/opt/sites/example.com/tmp'" 2>&1; false; fi
          > Executing if ! sudo su -u root whoami > /dev/null; then echo "You cannot switch to user 'root' using sudo, please check the sudoers file" 2>&1; false; fi
          > Executing cd /opt/sites/example.com/tmp && ( RAILS_ENV=production ( sudo su -u root /usr/bin/env touch restart.txt ) )
        EOEXPECTED
      end

      def test_capture
        File.open('/dev/null', 'w') do |dnull|
          Deploy.capture_output(dnull) do
            captured_command_result = ""
            Netssh.new(a_host) do |host|
              captured_command_result = capture(:hostname)
            end.run
            assert_equal "lucid32", captured_command_result
          end
        end
      end

      def test_exit_status

      end

      def test_raising_an_error_if_a_command_returns_a_bad_exit_status
        skip "Where to implement this?"
        # NOTE: I think that it might be wise to have Command raise when
        # Command#exit_status=() is called, it would allow an option to
        # be passed to command (raise_errors: false), which could also be
        # inherited through Backend#command and specified on the (not yet
        # existing) backend configurations.
        assert_raises RuntimeError do
          File.open('/dev/null', 'w') do |dnull|
            Deploy.capture_output(dnull) do
              Netssh.new(a_host) do |host|
                execute :false
              end.run
            end
          end
        end
      end

    end

  end

end
