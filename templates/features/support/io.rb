require 'stringio'

## Example:
## out, err = with_captured_io do
##   puts "wee!"
## end
##
## puts out  # => "wee!\n"

def with_captured_io
  sio_stdout = StringIO.new
  sio_stderr = StringIO.new
  _stdout, $stdout = $stdout, sio_stdout
  _stderr, $stderr = $stderr, sio_stderr
  begin
    # Call block with new stdout and stderr
    yield
  ensure
    $stdout = _stdout
    $stderr = _stderr
  end
  sio_stdout.seek(0)
  sio_stderr.seek(0)
  stdout, stderr = sio_stdout.read(), sio_stderr.read()
  return [stdout, stderr]
end
