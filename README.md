# SnakeBar.jl

A tqdm-like progress bar that fills your terminal with a one-character-thick snake along a random space-filling curve. Port of the Python [snakebar](https://github.com/majoburo/snakebar) package to Julia.

Based on [Random Space-Filling Curves](https://observablehq.com/@esperanc/random-space-filling-curves).

## Installation

### From local source

Add the package to your Julia environment:

```julia
using Pkg
Pkg.develop(path="path/to/SnakeBar.jl")
```

Or using the package manager:

```julia
] dev path/to/SnakeBar.jl
```

### From a Git repository

```julia
using Pkg
Pkg.add(url="https://github.com/majoburo/SnakeBar.jl")
```

### From Julia General Registry (when registered)

Once registered in the Julia General Registry:

```julia
using Pkg
Pkg.add("SnakeBar")
```

## Usage

### Basic Julia usage with do-block

Using `snake_bar` with a do-block:

```julia
using SnakeBar

snake_bar(1:100, desc="Processing") do i
    # your code here
    sleep(0.01)
end
```

### Manual progress bar updates

Using `SnakeBAR` for manual control:

```julia
using SnakeBar

bar = SnakeBAR(100, desc="Processing")
start!(bar)
try
    for i in 1:100
        # your code here
        sleep(0.01)
        update!(bar, 1)
    end
finally
    close!(bar)
end
```

### Iterator-style usage

You can also use `snake_bar` as an iterator wrapper (returns a Channel):

```julia
using SnakeBar

for item in snake_bar(1:100, desc="Processing")
    # your code here with item
    sleep(0.01)
end
```

### Multi-snake usage

Display multiple colored snakes progressing through the same maze:

```julia
using SnakeBar

# Using do-block (all snakes advance together)
multi_snake_bar(1:100, 3, desc="3 Snakes") do i
    # your code here
    sleep(0.01)
end

# Or as an iterator
for item in multi_snake_bar(1:100, 3, desc="3 Snakes")
    # your code here with item
    sleep(0.01)
end
```

Each snake will be displayed in a different color (bright red, bright green, bright yellow, etc.).

### Independent snake advancement (parallel processes)

Track parallel processes that advance at different rates:

```julia
using SnakeBar

# Create a multi-snake bar for 3 processes, each with 100 steps
bar = MultiSnakeBAR(100, 3, desc="3 Parallel Processes")
start!(bar)

try
    # Simulate 3 processes running at different speeds
    while true
        # Update snake 1 (process 1)
        if process1_has_work()
            update_snake!(bar, 1, 1)  # Advance snake 1 by 1 step
        end

        # Update snake 2 (process 2)
        if process2_has_work()
            update_snake!(bar, 2, 2)  # Advance snake 2 by 2 steps
        end

        # Update snake 3 (process 3)
        if process3_has_work()
            update_snake!(bar, 3, 1)  # Advance snake 3 by 1 step
        end

        # Check if all processes are done
        if all_done()
            break
        end

        sleep(0.01)
    end
finally
    close!(bar)
end
```

The status line will show individual progress for each snake: `S1:45/100 S2:78/100 S3:32/100`

### CLI usage

You can run the demo from the command line:

```bash
# Single snake
julia SnakeBar.jl/bin/snakebar.jl -n 200 --desc "Processing" --sleep 0.01

# Multiple colored snakes
julia SnakeBar.jl/bin/snakebar.jl -n 200 -s 3 --desc "3 Snakes" --sleep 0.01
```

Options:
- `-n`, `--total`: Total number of steps (default 200)
- `-s`, `--snakes`: Number of snakes to display (default 1, uses colors when > 1)
- `--desc`: Description text to show alongside the progress bar
- `--sleep`: Time in seconds to sleep between steps (simulates work)
- `--seed`: Random seed for reproducible snake paths
- `--ch`: Character to use for the snake (default: █)
- `--bg`: Background character (default: space)
- `-h`, `--help`: Show help message

## Features

- Single snake progress bar with customizable characters
- Multi-snake mode with colored snakes (each snake gets a different color via ANSI escape codes)
- Independent progress tracking for each snake - perfect for monitoring parallel processes
- Random space-filling curves generated each run (unless a seed is specified)
- tqdm-style status information (progress %, ETA, rate, and individual snake counters)
- Optimized rendering with rate limiting (60 FPS max) and efficient IOBuffer-based string building

## Differences from Python version

- Uses 1-based indexing (Julia convention)
- Uses `do`-blocks instead of context managers (`with` statement)
- Uses `start!()` and `close!()` instead of `__enter__` and `__exit__`
- Function names follow Julia conventions (`update!` instead of `update`)
- Terminal size detection uses Julia's `displaysize()`
- Uses `MersenneTwister` for random number generation
- Multi-snake mode uses ANSI colors instead of different characters

## API Reference

### `SnakeBAR`

Main struct for creating a snake progress bar.

**Constructor:**
```julia
SnakeBAR(total::Int;
         ch::Char='█',
         bg::Char=' ',
         seed::Union{Int, Nothing}=nothing,
         pad_x::Int=0,
         pad_y::Int=0,
         desc::String="")
```

**Methods:**
- `start!(bar)`: Initialize and display the progress bar
- `update!(bar, n=1)`: Advance progress by n steps
- `set_description!(bar, desc)`: Update the description text
- `close!(bar)`: Clean up and restore cursor

### `snake_bar`

Convenience function for wrapping iterables.

**Usage with do-block:**
```julia
snake_bar(f::Function, iterable; kwargs...)
```

**Usage as iterator:**
```julia
for item in snake_bar(iterable; kwargs...)
    # work with item
end
```

### `MultiSnakeBAR`

Multi-snake progress bar that displays multiple colored snakes in the same maze.

**Constructor:**
```julia
MultiSnakeBAR(total::Int, n_snakes::Int;
              ch::Char='█',
              colors::Union{Vector{String}, Nothing}=nothing,
              bg::Char=' ',
              seed::Union{Int, Nothing}=nothing,
              pad_x::Int=0,
              pad_y::Int=0,
              desc::String="")
```

**Parameters:**
- `total`: Total number of iterations
- `n_snakes`: Number of colored snakes to display
- `ch`: Character to use for all snakes (default: █)
- `colors`: Optional vector of ANSI color codes (auto-generated if not provided)
- `bg`: Background character
- `seed`: Random seed for reproducible paths
- `pad_x`, `pad_y`: Padding around the display
- `desc`: Description text

**Methods:**
- `start!(bar)`: Initialize and display the progress bar
- `update!(bar, n=1)`: Advance all snakes together by n steps (for uniform progress)
- `update_snake!(bar, snake_idx, n=1)`: Advance a specific snake by n steps (for independent progress tracking)
- `set_description!(bar, desc)`: Update the description text
- `close!(bar)`: Clean up and restore cursor

**Note:** Each snake maintains its own independent progress counter. Use `update_snake!` to track parallel processes advancing at different rates, or use `update!` to advance all snakes together uniformly.

### `multi_snake_bar`

Convenience function for multi-snake progress with iterables.

**Usage with do-block:**
```julia
multi_snake_bar(f::Function, iterable, n_snakes::Int; kwargs...)
```

**Usage as iterator:**
```julia
for item in multi_snake_bar(iterable, n_snakes::Int; kwargs...)
    # work with item
end
```

## License

MIT

## Credits

Original Python implementation by Majo Bustamante Rosell.
Based on the Observable notebook by Claudio Esperança.
