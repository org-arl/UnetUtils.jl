# UnetStack Utilities

`UnetUtils.jl` provides commonly used utilities that are helpful when working with UnetStack and Julia. Currently, it contains utilities to work with UnetStack signal dumps (`signals-*.txt` files) and passband recordings (`rec-*.dat` files).

## Installation

To install:
```julia
julia> # press ] for package mode
pkg> add UnetUtils
```

## Usage

### Signal dumps

To read a `signals.txt` file:

```julia
julia> using UnetUtils
julia> s = Signals.read("signals.txt")
5×11 DataFrame
 Row │ time                           rxtime       rssi      preamble  channels  fc       fs       len    lno    filename     dtype
     │ ZonedDat…                      Int64?       Float64?  Int64     Int64     Float64  Float64  Int64  Int64  String       DataType
─────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ 2024-02-09T14:12:02.757+08:00  19320296667     -67.0         2         4  24000.0  24000.0    720      2  signals.txt  ComplexF32
   2 │ 2024-02-09T14:12:11.238+08:00  19328782709     -66.9         2         4  24000.0  24000.0    720      5  signals.txt  ComplexF32
   3 │ 2024-02-09T14:12:15.967+08:00  19333509458     -66.8         2         4  24000.0  24000.0    720      8  signals.txt  ComplexF32
   4 │ 2024-02-09T14:12:19.405+08:00  19336950750     -67.0         2         4  24000.0  24000.0    720     11  signals.txt  ComplexF32
   5 │ 2024-02-09T14:12:28.830+08:00  19346376417     -67.0         2         4  24000.0  24000.0    720     14  signals.txt  ComplexF32
```
We can read a signal from the file:
```julia
julia> x = Signals.read(s, 2)     # read signal number 2
SampledSignal @ 24000.0 Hz, 720×4 Matrix{ComplexF64}:
  -8.90469e-5-0.000147327im   0.000127849+0.0002874im      1.72211e-5+0.0001782im     0.000185837+0.000201513im
  -7.16846e-5-0.000106024im   -6.52411e-5+9.06558e-5im    0.000214363-1.82419e-5im    -7.30673e-5+0.000159378im
 -0.000169725-0.000221368im   -5.35115e-5+0.000152804im   0.000218458+0.000330593im  -0.000158725-4.01946e-5im
 -0.000232667-0.000129752im  -0.000293527+5.65732e-6im   -0.000204773-8.53947e-5im    -6.13353e-6-7.99393e-6im
             ⋮                           ⋮                           ⋮                         ⋮
```
In this example, the signal was a 4-channel baseband signal, and so it was extracted as a 4-column complex matrix. If the signal is a passband signal, it is returned as a real matrix.

### Passband recordings

To read a passband recording `rec.dat`:
```julia
julia> using UnetUtils
julia> r = Recordings.read("rec.dat")
SampledSignal @ 256000.0 Hz, 14126592×4 Matrix{Float32}:
 -0.00142775  -0.00463575  -0.00311242  -0.00476095
 -0.00155232  -0.00470167  -0.00364076  -0.00472483
 -0.00146602  -0.00348717  -0.0026301   -0.00385222
 -0.00153838  -0.00462216  -0.00315212  -0.00466463
 -0.00173865  -0.00554317  -0.00420509  -0.00542805
 -0.00148247  -0.00300187  -0.00201665  -0.00302324
     ⋮             ⋮             ⋮            ⋮
```

If we have a directory full of recording files, we can also get an index of recordings to work with:
```julia
julia> r = Recordings.read("/my/recordings/")
15×5 DataFrame
 Row │ time                           filename   duration  nchannels  framerate
     │ ZonedDat…                      String     Float64   Int64      Float64
─────┼─────────────────────────────────────────────────────────────────────────
   1 │ 2023-12-22T16:09:36.885+08:00  rec-1703…  55.182            4   256000.0
   2 │ 2023-12-22T16:17:15.013+08:00  rec-1703…  53.837            4   256000.0
   3 │ 2024-02-08T20:00:07.835+08:00  rec-1707…  58.5094           4    96000.0
   4 │ 2024-02-08T20:24:11.641+08:00  rec-1707…  49.68             4    96000.0
   5 │ 2024-02-08T20:32:19.897+08:00  rec-1707…   3.44535          4    96000.0
   6 │ 2024-02-08T20:34:00.011+08:00  rec-1707…   2.41869          4    96000.0
   7 │ 2024-02-08T20:35:20.049+08:00  rec-1707…   3.19735          4    96000.0
   8 │ 2024-02-08T20:36:53.568+08:00  rec-1707…  44.864            4    96000.0
   9 │ 2024-02-08T20:41:32.275+08:00  rec-1707…  24.056            4    96000.0
  10 │ 2024-02-08T21:02:41.015+08:00  rec-1707…   5.94935          4    96000.0
  11 │ 2024-02-08T21:05:44.358+08:00  rec-1707…  31.6934           4    96000.0
  12 │ 2024-02-08T21:26:24.103+08:00  rec-1707…  28.4507           4    96000.0
  13 │ 2024-02-08T21:28:13.746+08:00  rec-1707…  16.7814           4    96000.0
  14 │ 2024-02-08T21:34:07.463+08:00  rec-1707…  27.832            4    96000.0
  15 │ 2024-02-15T14:41:25.645+08:00  rec-1707…   5.46801          4   256000.0
```
and then work with individual recordings:
```julia
julia> x = Recordings.read(r, 3)        # load recording 3
```
Recordings are always in passband and are returned as matrices of real numbers. The number of columns is equal to the number of channels in the recording.

We can also ask for a recording to be converted to a WAV file:
```julia
julia> Recordings.towav("rec.dat")
```
This will create a `rec.wav` file in the same folder as the original recording.
