using Test
include("../common/validation/saved_data.jl")
@testset "Independent saved-data validation" begin
    clearance=p->box_clearance(p,(1.0,1.0,1.0))
    p=[0.25 0.75;0.5 0.5;0.5 0.5];r=[0.1,0.1]
    @test check_assembly(p,r,clearance;requested_count=2,tolerance=1e-6)["geometric_validation_passed"]
    coincident=copy(p);coincident[:,2]=coincident[:,1]
    @test maximum(pair_penetrations(coincident,r))≈0.2
    @test !check_assembly(coincident,r,clearance;requested_count=2,tolerance=1e-6)["geometric_validation_passed"]
    outside=copy(p);outside[1,1]=-0.1
    @test !check_assembly(outside,r,clearance;requested_count=2,tolerance=1e-6)["geometric_validation_passed"]
    @test !check_assembly(p,r,clearance;requested_count=3,tolerance=1e-6)["geometric_validation_passed"]
    @test_throws AssertionError check_assembly(fill(NaN,3,2),r,clearance;requested_count=2,tolerance=1e-6)
end
