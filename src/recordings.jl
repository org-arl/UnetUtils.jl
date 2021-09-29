module Recordings

import SignalAnalysis: signal
import Statistics: mean
import DataFrames: DataFrame, DataFrameRow
import TimeZones: localzone, ZonedDateTime, astimezone, @tz_str
import Dates: unix2datetime

const FRAMERATE = 32000.0
const NCHANNELS = 4

function read(filename; tz=localzone())
  isfile(filename) && return readrec(filename)
  df = DataFrame(time=ZonedDateTime[], filename=String[], duration=Float64[])
  for filename ∈ readdir(filename; join=true)
    m = match(r"/?rec\-(\d+)\.dat", filename)
    if m !== nothing
      t = astimezone(ZonedDateTime(unix2datetime(parse(Int64, m[1]) / 1000), tz"UTC"), tz)
      d = stat(filename).size / (4 * NCHANNELS * FRAMERATE)
      push!(df, (t, filename, d))
    end
  end
  sort!(df, :time)
end

read(filenames::AbstractVector; tz=localzone()) = sort!(vcat(read.(filenames; tz)...), :time)

read(row::DataFrameRow) = readrec(row.filename)
read(df::DataFrame, i) = readrec(df.filename[i])

function readrec(filename)
  open(filename, "r") do f
    bytes = Base.read(f)
    raw = reinterpret(Float32, bytes)
    x = signal(reshape(raw, NCHANNELS, :)', FRAMERATE)
    x .- mean(1.0x; dims=1)
  end
end

end # module
