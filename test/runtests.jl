using FileIO
using Base.Test

add_format(format"KLB", (), ".klb", [:KLB])

const testdata_filename = "deleteme.klb"
const testdata_dtype = UInt16
const testdata_size = [521, 521, 64]
const testdata_lower_bounds = UInt32[1, 1, 1, 1, 1]
const testdata_upper_bounds = UInt32[64, 64, 32, 1, 1]
const testdata_bounds = cat(2, testdata_lower_bounds, testdata_upper_bounds)

save(testdata_filename, rand(testdata_dtype, testdata_size...));
@test isfile(testdata_filename) == true

A = load(testdata_filename)
@test eltype(A) == testdata_dtype
@test prod(size(A)) == prod(testdata_size)
@test mean(A) != 0

A = zeros(testdata_dtype, testdata_size...)
load(testdata_filename, inplace=A, nochecks=true)
@test mean(A) != 0

A = load(testdata_filename, bounds=testdata_bounds)
@test eltype(A) == testdata_dtype
@test prod(size(A)) == prod(testdata_upper_bounds)
@test mean(A) != 0

A = zeros(testdata_dtype, testdata_upper_bounds...)
load(testdata_filename, bounds=testdata_bounds, inplace=A, nochecks=true)
@test mean(A) != 0

using KLB

header = klbheader(testdata_filename)
@test header["datatype"] == testdata_dtype
@test prod(header["imagesize"]) == prod(testdata_size)

A = KLB.loadklb(testdata_filename)
@test eltype(A) == testdata_dtype
@test prod(size(A)) == prod(testdata_size)
@test mean(A) != 0

A = zeros(testdata_dtype, testdata_size...)
KLB.loadklb!(A, testdata_filename)
@test mean(A) != 0

A = KLB.loadklb(testdata_filename, testdata_lower_bounds, testdata_upper_bounds)
@test eltype(A) == testdata_dtype
@test prod(size(A)) == prod(testdata_upper_bounds)
@test mean(A) != 0

A = zeros(testdata_dtype, testdata_upper_bounds...)
KLB.loadklb!(A, testdata_filename, testdata_lower_bounds, testdata_upper_bounds)
@test mean(A) != 0

rm(testdata_filename)
@test isfile(testdata_filename) == false
