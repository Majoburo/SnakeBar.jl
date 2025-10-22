#!/usr/bin/env julia

# Example usage of SnakeBar

using SnakeBar

println("Example 1: Manual usage with start!/close!")
println("Press Enter to start...")
readline()

bar = SnakeBAR(50, desc="Example 1")
start!(bar)
try
    for i in 1:50
        sleep(0.05)
        update!(bar, 1)
    end
finally
    close!(bar)
end

println("\nExample 1 complete!\n")
sleep(1)

println("Example 2: Using do-block syntax")
println("Press Enter to start...")
readline()

snake_bar(1:50, desc="Example 2") do i
    sleep(0.05)
end

println("\nExample 2 complete!\n")
sleep(1)

println("Example 3: Different character")
println("Press Enter to start...")
readline()

snake_bar(1:50, desc="Example 3", ch='#') do i
    sleep(0.05)
end

println("\nAll examples complete!")
println("\nFor an example of tracking parallel processes with independent snake advancement,")
println("run: julia example_parallel.jl")
