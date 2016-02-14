using KLB
using Base.Test

const testdata_filename = "deleteme.klb"
const testdata_dtype = UInt16
const testdata_size = [521, 521, 64]
const testdata_lower_bounds = UInt32[1, 1, 1, 1, 1]
const testdata_upper_bounds = UInt32[64, 64, 32, 1, 1]

KLB.writearray(testdata_filename, rand(testdata_dtype, testdata_size...));
@test isfile(testdata_filename) == true

header = KLB.readheader(testdata_filename)
@test header["datatype"] == testdata_dtype
@test prod(header["imagesize"]) == prod(testdata_size)

A = KLB.readarray(testdata_filename)
@test eltype(A) == testdata_dtype
@test prod(size(A)) == prod(testdata_size)
@test mean(A) != 0

A = zeros(testdata_dtype, testdata_size...)
KLB.readarray!(A, testdata_filename)
@test mean(A) != 0

A = KLB.readarray(testdata_filename, testdata_lower_bounds, testdata_upper_bounds)
@test eltype(A) == testdata_dtype
@test prod(size(A)) == prod(testdata_upper_bounds)
@test mean(A) != 0

A = zeros(testdata_dtype, testdata_upper_bounds...)
KLB.readarray!(A, testdata_filename, testdata_lower_bounds, testdata_upper_bounds)
@test mean(A) != 0

rm(testdata_filename)
@test isfile(testdata_filename) == false
