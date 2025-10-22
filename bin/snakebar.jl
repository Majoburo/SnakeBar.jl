#!/usr/bin/env julia

# CLI entry point for SnakeBar

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using SnakeBar

function parse_args()
    args = Dict{Symbol, Any}(
        :total => 200,
        :desc => "Snaking...",
        :seed => nothing,
        :ch => '█',
        :bg => ' ',
        :sleep => 0.01,
        :snakes => 1,
    )

    i = 1
    while i <= length(ARGS)
        arg = ARGS[i]
        if arg in ["-n", "--total"]
            args[:total] = parse(Int, ARGS[i+1])
            i += 2
        elseif arg == "--desc"
            args[:desc] = ARGS[i+1]
            i += 2
        elseif arg == "--seed"
            args[:seed] = parse(Int, ARGS[i+1])
            i += 2
        elseif arg == "--ch"
            args[:ch] = first(ARGS[i+1])
            i += 2
        elseif arg == "--bg"
            args[:bg] = first(ARGS[i+1])
            i += 2
        elseif arg == "--sleep"
            args[:sleep] = parse(Float64, ARGS[i+1])
            i += 2
        elseif arg in ["-s", "--snakes"]
            args[:snakes] = parse(Int, ARGS[i+1])
            i += 2
        elseif arg in ["-h", "--help"]
            println("""
            SnakeBar - tqdm-like progress bar that snakes across your terminal

            Usage: julia snakebar.jl [options]

            Options:
              -n, --total N     Total number of steps (default: 200)
              -s, --snakes N    Number of snakes (default: 1)
              --desc TEXT       Label printed above the bar (default: "Snaking...")
              --seed N          Random seed for the path
              --ch CHAR         Character used for the snake (default: █)
              --bg CHAR         Background character (default: space)
              --sleep SECONDS   Sleep per step for demo (default: 0.01)
              -h, --help        Show this help message
            """)
            exit(0)
        else
            println("Unknown argument: $arg")
            println("Use -h or --help for usage information")
            exit(1)
        end
    end

    return args
end

function main()
    args = parse_args()

    if args[:snakes] > 1
        # Multi-snake mode
        bar = MultiSnakeBAR(args[:total], args[:snakes];
                            desc=args[:desc],
                            seed=args[:seed],
                            bg=args[:bg])
    else
        # Single snake mode
        bar = SnakeBAR(args[:total];
                       desc=args[:desc],
                       seed=args[:seed],
                       ch=args[:ch],
                       bg=args[:bg])
    end

    start!(bar)
    iterations = 0
    try
        for i in 1:args[:total]
            iterations = i
            sleep(max(0.0, args[:sleep]))
            update!(bar, 1)
        end
        println("\nCompleted all $iterations iterations")
    catch e
        println("\nError at iteration $iterations: $e")
        rethrow()
    finally
        close!(bar)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
