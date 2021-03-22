module KLB

using FileIO
using Libdl
using UUIDs
import Base.convert

export klbheader, loadklb, loadklb!, klbtype


const KLB_DATA_DIMS = 5
const DEFAULT_NUMTHREADS = Sys.CPU_THREADS ÷ 2

# FileIO
function load(
    file::File{format"KLB"}
    ;
    bounds::Array{UInt32} = UInt32[0],
    numthreads::Int = DEFAULT_NUMTHREADS,
    inplace::AbstractArray = UInt8[0],
    nochecks::Bool = false
    )
    if length(bounds) != 1
        if length(inplace) != 1
            loadklb!(inplace, filename(file), bounds[:,1], bounds[:,2], numthreads=numthreads, nochecks=nochecks)
        else
            loadklb(filename(file), bounds[:,1], bounds[:,2], numthreads=numthreads)
        end
    else
        if length(inplace) != 1
            loadklb!(inplace, filename(file), numthreads=numthreads, nochecks=nochecks)
        else
            loadklb(filename(file), numthreads=numthreads)
        end
    end
end

# FileIO
function save(
    file::File{format"KLB"},
    A::AbstractArray
    ;
    numthreads::Int = DEFAULT_NUMTHREADS
    )
    writearray(filename(file), A, numthreads)
end


function klbheader( file::AbstractString )
    imagesize = zeros(UInt32, KLB_DATA_DIMS)
    blocksize = zeros(UInt32, KLB_DATA_DIMS)
    pixelspacing = ones(Float32, KLB_DATA_DIMS)
    ktype = Ref{Cint}(-1)
    compressiontype = Ref{Cint}(-1)
    metadata = repeat(" ", 256)

    errid = ccall( (:readKLBheader, "klb"), Cint,
        (Cstring, Ptr{UInt32}, Ref{Cint}, Ptr{Float32}, Ptr{UInt32}, Ref{Cint}, Ptr{Cchar}),
        file, imagesize, ktype, pixelspacing, blocksize, compressiontype, metadata)

    if errid != 0
        error("Could not read KLB header of file '$file'. Error code $errid")
    end

    Dict{AbstractString, Any}(
        "imagesize" => round.(Int, imagesize),
        "blocksize" => round.(Int, blocksize),
        "pixelspacing" => pixelspacing,
        "metadata" => strip(metadata),
        "datatype" => juliatype(ktype[]),
        "compressiontype" => compressiontype[],
        "spatialorder" => ["x", "y", "z"],
        "colordim" => 4,
        "timedim" => 5)
end


function loadklb(
    file::AbstractString
    ;
    numthreads::Int = DEFAULT_NUMTHREADS
    )
    header = klbheader(file)
    A = Array{header["datatype"]}(undef, header["imagesize"]...)
    loadklb!(A, file, numthreads=numthreads, nochecks=true)
    A
end


function loadklb!(
    A::AbstractArray,
    file::AbstractString
    ;
    numthreads::Int = DEFAULT_NUMTHREADS,
    nochecks::Bool = false
    )
    if !nochecks
        header = klbheader(file)
        @assert header["datatype"] == eltype(A)
        imagesize = header["imagesize"]
        for d in 1:KLB_DATA_DIMS
            @assert imagesize[d] == size(A, d)
        end
    end

    errid = ccall( (:readKLBstackInPlace, "klb"), Cint,
        (Cstring, Ptr{Cvoid}, Ref{Cint}, Cint),
        file, A, Ref{Cint}(0), numthreads)

    if errid != 0
        error("Could not read KLB file '$file'. Error code $errid")
    end
end


function loadklb(
    file::AbstractString,
    lower_bounds::Vector{UInt32},
    upper_bounds::Vector{UInt32}
    ;
    numthreads::Int = DEFAULT_NUMTHREADS
    )
    header = klbheader(file)
    roisize = 1 .+ upper_bounds .- lower_bounds
    A = Array{header["datatype"]}(undef, roisize...)
    loadklb!(A, file, lower_bounds, upper_bounds, numthreads=numthreads, nochecks=true)
    A
end


function loadklb!(
    A::AbstractArray,
    file::AbstractString,
    lower_bounds::Union{ Vector{UInt32}, NTuple{KLB_DATA_DIMS} },
    upper_bounds::Union{ Vector{UInt32}, NTuple{KLB_DATA_DIMS} }
    ;
    numthreads::Int = DEFAULT_NUMTHREADS,
    nochecks::Bool = false
    )
    lb = lower_bounds .- UInt32(1)
    ub = upper_bounds .- UInt32(1)

    if !nochecks
        header = klbheader(file)
        @assert header["datatype"] == eltype(A)
        roisize = 1 .+ ub .- lb
        for d in 1:5
            @assert roisize[d] == size(A, d) 
        end
    end

    errid = _readKLBroiInPlace(A, file, lb, ub, numthreads)

    if errid != 0
        error("Could not read KLB file '$file'. Error code $errid")
    end
    A
end

# Vector UInt32
function _readKLBroiInPlace(
    A::AbstractArray,
    file::AbstractString,
    lb::Vector{UInt32},
    ub::Vector{UInt32},
    numthreads::Int
)
    ccall( (:readKLBroiInPlace, "klb"), Cint,
        (Cstring, Ptr{Cvoid}, Ptr{UInt32}, Ptr{UInt32}, Cint),
        file, A, lb, ub, numthreads)
end

# NTuple{KLB_DATA_DIMS,T}
function _readKLBroiInPlace(
    A::AbstractArray,
    file::AbstractString,
    lb::NTuple{KLB_DATA_DIMS,T},
    ub::NTuple{KLB_DATA_DIMS,T},
    numthreads::Int
) where T
    ccall( (:readKLBroiInPlace, "klb"), Cint,
        (Cstring, Ptr{Cvoid}, NTuple{5,UInt32}, NTuple{5,UInt32}, Cint),
        file, A, (lb...,), (ub...,), numthreads)
end


function writearray(
    filepath::AbstractString,
    A::AbstractArray,
    numthreads::Int = DEFAULT_NUMTHREADS
    ;
    pixelspacing = C_NULL,
    blocksize = C_NULL,
    compressiontype::Int = 1,
    metadata = C_NULL
    )
    ktype = klbtype(eltype(A))
    imagesize = UInt32[i for i in size(A)]
    while length(imagesize) < 5
        push!(imagesize, 1)
    end

    errid = ccall( (:writeKLBstack, "klb"), Cint,
        (Ptr{Cvoid}, Cstring, Ptr{UInt32}, Cint, Cint, Ptr{Float32}, Ptr{UInt32}, Cint, Ptr{Cchar}),
        A, filepath, imagesize, ktype, numthreads, pixelspacing, blocksize, compressiontype, metadata)

    if errid != 0
        error("Could not write KLB file '$filepath'. Error code $errid")
    end
end


@enum klbtype::Cint begin
    KLB_UInt8   = 0
    KLB_UInt16  = 1
    KLB_UInt32  = 2
    KLB_UInt64  = 3
    KLB_Int8    = 4
    KLB_Int16   = 5
    KLB_Int32   = 6
    KLB_Int64   = 7
    KLB_Float32 = 8
    KLB_Float64 = 9
end

function juliatype( _klbtype )
    _klbtype = klbtype(_klbtype)
    if     _klbtype == KLB_UInt8  # 0
        return UInt8
    elseif _klbtype == KLB_UInt16 # 1
        return UInt16
    elseif _klbtype == KLB_UInt32 # 2
        return UInt32
    elseif _klbtype == KLB_UInt64 # 3
        return UInt64
    elseif _klbtype == KLB_Int8   # 4
        return Int8
    elseif _klbtype == KLB_Int16  # 5
        return Int16
    elseif _klbtype == KLB_Int32  # 6
        return Int32
    elseif _klbtype == KLB_Int64  # 7
        return Int64
    elseif _klbtype == KLB_Float32 # 8
        return Float32
    elseif _klbtype == KLB_Float64 # 9
        return Float64
    end
    error( "Unknown or unsupported data type of KLB array: $klbtype" )
end


klbtype(::Type{UInt8}  )  = KLB_UInt8   # 0
klbtype(::Type{UInt16} )  = KLB_UInt16  # 1
klbtype(::Type{UInt32} )  = KLB_UInt32  # 2
klbtype(::Type{UInt64} )  = KLB_UInt64  # 3
klbtype(::Type{Int8}   )  = KLB_Int8    # 4
klbtype(::Type{Int16}  )  = KLB_Int16   # 5
klbtype(::Type{Int32}  )  = KLB_Int32   # 6
klbtype(::Type{Int64}  )  = KLB_Int64   # 7
klbtype(::Type{Float32})  = KLB_Float32 # 8
klbtype(::Type{Float64})  = KLB_Float64 # 9
klbtype(k::klbtype) = k

function klbtype( juliatype::Type )
    #=
    if juliatype == UInt8
        return 0
    elseif juliatype == UInt16
        return 1
    elseif juliatype == UInt32
        return 2
    elseif juliatype == UInt64
        return 3
    elseif juliatype == Int8
        return 4
    elseif juliatype == Int16
        return 5
    elseif juliatype == Int32
        return 6
    elseif juliatype == Int64
        return 7
    elseif juliatype == Float32
        return 8
    elseif juliatype == Float64
        return 9
    end
    =#
    error( "Unknown or unsupported data type of KLB array: $juliatype" )
end

convert(::DataType, klb::klbtype ) = juliatype(klb)

function __init__()
    klb_deps_folder = joinpath(dirname(dirname(@__FILE__)), "deps")
    global library_location
    library_location = Libdl.find_library(["klb","libklb"],[klb_deps_folder])
    if isempty(library_location)
        error("[lib]klb.$(Libdl.dlext) library could not be located in $klb_deps_folder or elsewhere.")
    else
        @info "$library_location.$(Libdl.dlext)"
        Libdl.dlopen(library_location)
    end
    add_format(format"KLB", (), ".klb", [:KLB => UUID("8bb66c0d-974d-412d-8f46-f9b8d1ef37d0")])
end

end # module
