using UnetUtils
using SignalAnalysis
using Test

@testset "recordings" begin
  dir = mktempdir()
  x = signal(Float32.(reshape(1:4000, 1000, 4)) ./ 4000, 160000)
  UnetUtils.Recordings.write(joinpath(dir, "rec-1788838933179.dat"), x; rxtime=1234567890123)
  # older header: zeros where rxtime now lives
  open(joinpath(dir, "rec-1788838900000.dat"), "w") do io
    write(io, hton(0x43c04d126f173001), Int64(1788838900000), Int32(160000), Int16(4), zeros(UInt16, 5))
    write(io, Float32.(samples(x)'))
  end
  df = UnetUtils.Recordings.read(dir)
  @test size(df, 1) == 2
  @test df.rxtime == [0, 1234567890123]
  @test df.nchannels == [4, 4]
  @test df.framerate == [160000.0, 160000.0]
  @test df.duration ≈ [1000 / 160000, 1000 / 160000]
  for i ∈ 1:2
    y = UnetUtils.Recordings.read(df, i)
    @test framerate(y) == 160000
    @test size(y) == (1000, 4)
    @test samples(y) ≈ samples(x) .- sum(samples(x); dims=1) ./ 1000
  end
  open(joinpath(dir, "rec-1788838933179.dat")) do io
    hdr = UnetUtils.Recordings.read(io, UnetUtils.Recordings.RecordingHeader)
    @test hdr.rxtime == 1234567890123
    @test position(io) == 32
  end
end
