#!/usr/bin/env julia

# Example: Track 3 parallel processes advancing at different rates

using SnakeBar

println("Example: 3 parallel processes advancing at different rates")
println("Each snake represents a different process with its own speed")
println("Press Enter to start...")
readline()

# Create a multi-snake bar for 3 processes, each with 100 total steps
bar = MultiSnakeBAR(100, 3, desc="3 Parallel Processes")
start!(bar)

try
    # Simulate 3 processes running at different speeds
    # Process 1 (Snake 1): Fast - completes in ~1 second
    # Process 2 (Snake 2): Medium - completes in ~2 seconds
    # Process 3 (Snake 3): Slow - completes in ~3 seconds

    snake1_done = false
    snake2_done = false
    snake3_done = false

    snake1_progress = 0
    snake2_progress = 0
    snake3_progress = 0

    while !snake1_done || !snake2_done || !snake3_done
        # Update snake 1 (fastest) - 3 steps per iteration
        if !snake1_done && snake1_progress < 100
            advance = min(3, 100 - snake1_progress)
            update_snake!(bar, 1, advance)
            snake1_progress += advance
            if snake1_progress >= 100
                snake1_done = true
            end
        end

        # Update snake 2 (medium) - 2 steps per iteration
        if !snake2_done && snake2_progress < 100
            advance = min(2, 100 - snake2_progress)
            update_snake!(bar, 2, advance)
            snake2_progress += advance
            if snake2_progress >= 100
                snake2_done = true
            end
        end

        # Update snake 3 (slowest) - 1 step per iteration
        if !snake3_done && snake3_progress < 100
            advance = min(1, 100 - snake3_progress)
            update_snake!(bar, 3, advance)
            snake3_progress += advance
            if snake3_progress >= 100
                snake3_done = true
            end
        end

        sleep(0.03)
    end
finally
    close!(bar)
end

println("\nAll processes complete!")
println("Snake 1 (red) was fastest, Snake 2 (green) medium, Snake 3 (yellow) slowest")
