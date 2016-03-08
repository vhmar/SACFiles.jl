const DATA_START = 632 # Start byte for a SAC file's data section

"Read the SAC file stream `f`. Returns a subtype of `AbstractSACData` determined
using the file's header's `iftype` and `leven` variables. Note that this
function isn't type-stable and so shouldn't be used in performance sensitive
code."
readsac(fname::AbstractString) = open(readsac, fname)
function readsac(f::IOStream)
    hdr = readsachdr(f)

    if hdr.iftype == itime && hdr.leven
        readsac(EvenTimeSeries, f, hdr)
    elseif hdr.iftype == itime && !hdr.leven
        readsac(UnevenTimeSeries, f, hdr)
    elseif hdr.iftype == irlim
        readsac(ComplexSpectrum, f, hdr)
    elseif hdr.iftype == iamph
        readsac(AmplitudeSpectrum, f, hdr)
    elseif hdr.iftype == ixy
        readsac(GeneralXY, f, hdr)
    end
end

"Read an evenly spaced time series SAC file from the stream `f`. Returns an
instance of `EvenTimeSeries`."
readsac(T::Type{EvenTimeSeries}, f::IOStream) = readsac(T, f, readsachdr(f))
function readsac(T::Type{EvenTimeSeries}, f::IOStream, hdr::Header)
    if hdr.iftype != itime || !hdr.leven
        error("File's header indicates it is not an even time series.")
    end
    EvenTimeSeries(hdr, readsac_data(f, hdr.npts)[1])
end

"Read an unevenly spaced time series SAC file from the stream `f`. Returns an
instance of `UnevenTimeSeries`."
readsac(T::Type{UnevenTimeSeries}, f::IOStream) = readsac(T, f, readsachdr(f))
function readsac(T::Type{UnevenTimeSeries}, f::IOStream, hdr::Header)
    if hdr.iftype != itime || hdr.leven
        error("File's header indicates it is not an uneven time series.")
    end
    UnevenTimeSeries(hdr, readsac_data(f, hdr.npts)...)
end

"Read an amplitude/phase SAC file from the stream `f`. Returns an instance of
`AmplitudeSpectrum`."
readsac(T::Type{AmplitudeSpectrum}, f::IOStream) = readsac(T, f, readsachdr(f))
function readsac(T::Type{AmplitudeSpectrum}, f::IOStream, hdr::Header)
    if hdr.iftype != iamph
        error("File's header indicates it is not an amplitude/phase spectrum.")
    end
    AmplitudeSpectrum(hdr, readsac_data(f, hdr.npts)...)
end

"Read a complex/imaginary SAC file from the stream `f`. Returns an instance of
`ComplexSpectrum`."
readsac(T::Type{ComplexSpectrum}, f::IOStream) = readsac(T, f, readsachdr(f))
function readsac(T::Type{ComplexSpectrum}, f::IOStream, hdr::Header)
    if hdr.iftype != irlim
        error("File's header indicates it is not a real/imaginary spectrum.")
    end
    ComplexSpectrum(hdr, complex(readsac_data(f, hdr.npts)...))
end

"Read a general XY sac file from the stream `f`. Returns an instance of
`SACGenrealXY`."
readsac(T::Type{GeneralXY}, f::IOStream) = readsac(T, f, readsachdr(f))
function readsac(T::Type{GeneralXY}, f::IOStream, hdr::Header)
    if hdr.iftype != ixy
        error("File's header indicates it is not a general x vs. y file.")
    end
    GeneralXY(hdr, reverse(readsac_data(f, hdr.npts))...)
end

"Reads the data section from a file and returns a tuple containing the first and
second data (might be empty) sections. Return type `Tuple{Array{Float32,1},
Array{Float32,1}}."
function readsac_data(f::IOStream, npts::Int32)
    needswap = isalienend(f)
    seek(f, DATA_START)

    data1 = reinterpret(Float32, readbytes(f, SAC_WORD_SIZE * npts))
    if eof(f)
        return needswap ? (map!(bswap, data1), Float32[]) : (data1, Float32[])
    end

    data2 = reinterpret(Float32, readbytes(f, SAC_WORD_SIZE * npts))

    return needswap ? (map!(bswap, data1), map!(bswap, data2)) : (data1, data2)
end
