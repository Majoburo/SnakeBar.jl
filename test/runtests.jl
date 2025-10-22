using Test
using SnakeBar

@testset "SnakeBar.jl Tests" begin
    @testset "Basic Construction" begin
        bar = SnakeBAR(10, desc="Test")
        @test bar.total == 10
        @test bar.desc == "Test"
        @test bar._progress == 0
    end

    @testset "Spanning Tree Generation" begin
        st = SnakeBar.grid_spanning_tree(5, 5, seed=42)
        @test length(st.edges) == 24  # 5x5 grid has 24 edges in spanning tree
        @test st.nrows == 5
        @test st.ncols == 5
    end

    @testset "Hamiltonian Path Generation" begin
        st = SnakeBar.grid_spanning_tree(5, 5, seed=42)
        ham = SnakeBar.hamiltonian_from_spanning_tree(st)
        @test length(ham.path) == 100  # Doubled grid: (2*5) * (2*5) = 100
        @test ham.nrows == 10
        @test ham.ncols == 10
    end

    @testset "Single Snake Progress" begin
        bar = SnakeBAR(5, desc="Test", seed=42)
        bar._start_time = time()
        bar._progress = 0

        update!(bar, 1)
        @test bar._progress == 1

        update!(bar, 4)
        @test bar._progress == 5
        @test bar._drawn_upto == length(bar.draw_seq)  # Should fill entire path at 100%
    end

    @testset "Multi-Snake Construction" begin
        bar = MultiSnakeBAR(10, 3, desc="Test")
        @test bar.total == 10
        @test bar.n_snakes == 3
        @test length(bar._progress) == 3
        @test all(bar._progress .== 0)
    end

    @testset "Independent Snake Advancement" begin
        bar = MultiSnakeBAR(10, 3, desc="Test")
        bar._start_time = time()
        bar._progress = [0, 0, 0]

        update_snake!(bar, 1, 5)
        update_snake!(bar, 2, 3)
        update_snake!(bar, 3, 7)

        @test bar._progress == [5, 3, 7]

        # Test update! updates all snakes
        update!(bar, 2)
        @test bar._progress == [7, 5, 9]
    end

    @testset "Complete Path Filling at 100%" begin
        # Single snake
        bar = SnakeBAR(100, desc="Test", seed=42)
        bar._start_time = time()
        update!(bar, 100)
        @test bar._drawn_upto == length(bar.draw_seq)

        # Multi-snake
        mbar = MultiSnakeBAR(100, 3, desc="Test", seed=42)
        mbar._start_time = time()
        for i in 1:3
            update_snake!(mbar, i, 100)
        end

        # Check all snakes completed their segments
        for i in 1:3
            expected = length(mbar.snake_segments[i])
            @test mbar._drawn_upto[i] == expected
        end

        # Verify no empty cells
        empty_count = 0
        for (y, x) in mbar.draw_seq
            if mbar.canvas[y][x] == mbar.bg
                empty_count += 1
            end
        end
        @test empty_count == 0
    end

    @testset "Many Snakes Completion" begin
        # Test with 60 snakes to verify end-game optimization
        bar = MultiSnakeBAR(100, 60, desc="Test", seed=42)
        bar._start_time = time()

        for _ in 1:100
            update!(bar, 1)
        end

        # Verify no empty cells
        empty_count = 0
        for (y, x) in bar.draw_seq
            if bar.canvas[y][x] == bar.bg
                empty_count += 1
            end
        end
        @test empty_count == 0
    end
end
