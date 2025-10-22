module SnakeBar

export SnakeBAR, snake_bar, start!, update!, set_description!, close!, MultiSnakeBAR, multi_snake_bar, update_snake!

using Random
using Printf

# Type aliases for clarity
const Index = Int
const Edge = Tuple{Index, Index}

# Data structures
struct SpanningTree
    nrows::Int
    ncols::Int
    edges::Vector{Edge}
    connect::Vector{Dict{Symbol, Bool}}  # Dict(:left=>bool, :right=>bool, :up=>bool, :down=>bool)
end

struct Hamiltonian
    nrows::Int
    ncols::Int
    path::Vector{Index}
end

# Utility functions
_row(i::Int, ncols::Int) = div(i - 1, ncols) + 1  # 1-indexed
_col(i::Int, ncols::Int) = mod(i - 1, ncols) + 1  # 1-indexed

function grid_spanning_tree(ncols::Int, nrows::Int; seed::Union{Int, Nothing}=nothing)::SpanningTree
    """
    Create a random spanning tree over an ncols x nrows grid using DFS with shuffled neighbors.
    """
    # Generate a truly random seed if none provided
    actual_seed = seed === nothing ? rand(UInt32) : seed
    rng = MersenneTwister(actual_seed)
    N = ncols * nrows
    visited = falses(N)
    edges = Edge[]

    function neighbors(k::Int)::Vector{Int}
        i, j = _col(k, ncols), _row(k, ncols)
        ns = Int[]
        if i > 1
            push!(ns, k - 1)  # left
        end
        if j > 1
            push!(ns, k - ncols)  # up
        end
        if i < ncols
            push!(ns, k + 1)  # right
        end
        if j < nrows
            push!(ns, k + ncols)  # down
        end
        shuffle!(rng, ns)
        return ns
    end

    function visit(k::Int)
        visited[k] = true
        for n in neighbors(k)
            if !visited[n]
                push!(edges, (k, n))
                visit(n)
            end
        end
    end

    start = rand(rng, 1:N)
    visit(start)

    # Build connection map
    connect = [Dict(:left=>false, :right=>false, :up=>false, :down=>false) for _ in 1:N]
    for (a, b) in edges
        i, j = a <= b ? (a, b) : (b, a)
        # same row: horizontal
        if _row(i, ncols) == _row(j, ncols)
            connect[i][:right] = true
            connect[j][:left] = true
        else
            # vertical
            connect[i][:down] = true
            connect[j][:up] = true
        end
    end

    return SpanningTree(nrows, ncols, edges, connect)
end

function hamiltonian_from_spanning_tree(st::SpanningTree)::Hamiltonian
    """
    Convert the grid spanning tree to a Hamiltonian path on the doubled grid,
    following the same construction as the Observable notebook.
    """
    nrows2, ncols2 = 2 * st.nrows, 2 * st.ncols
    N2 = nrows2 * ncols2
    edges2 = Edge[]

    function index2(i::Int, dcol::Int, drow::Int)::Int
        return ((_row(i, st.ncols) - 1) * 2 + drow) * ncols2 + ((_col(i, st.ncols) - 1) * 2 + dcol) + 1
    end

    # Build the doubled-grid edges according to the local connect flags
    for (i, cell) in enumerate(st.connect)
        left, right, up, down = cell[:left], cell[:right], cell[:up], cell[:down]

        # Right edge(s)
        if right
            push!(edges2, (index2(i, 1, 0), index2(i, 2, 0)))
            push!(edges2, (index2(i, 1, 1), index2(i, 2, 1)))
        else
            push!(edges2, (index2(i, 1, 0), index2(i, 1, 1)))
        end

        # Left boundary (if no left connection)
        if !left
            push!(edges2, (index2(i, 0, 0), index2(i, 0, 1)))
        end

        # Down edge(s)
        if down
            push!(edges2, (index2(i, 0, 1), index2(i, 0, 2)))
            push!(edges2, (index2(i, 1, 1), index2(i, 1, 2)))
        else
            push!(edges2, (index2(i, 0, 1), index2(i, 1, 1)))
        end

        # Up boundary (if no up connection)
        if !up
            push!(edges2, (index2(i, 0, 0), index2(i, 1, 0)))
        end
    end

    # Build 2-regular graph adjacency (each vertex has degree 2)
    links = [Int[] for _ in 1:N2]
    for (a, b) in edges2
        push!(links[a], b)
        push!(links[b], a)
    end

    # Walk the cycle to produce a single Hamiltonian path over all doubled-grid nodes
    visited = falses(N2)
    j = 1
    path = Int[]
    for _ in 1:length(edges2)
        push!(path, j)
        visited[j] = true
        a, b = links[j][1], links[j][2]
        j = visited[a] ? b : a
    end

    return Hamiltonian(nrows2, ncols2, path)
end

function _terminal_size()::Tuple{Int, Int}
    # Get terminal size (columns, lines)
    # Use displaysize which returns (rows, cols) in Julia
    rows, cols = displaysize(stdout)
    return (cols, rows)
end

function _build_interleaved_canvas(nrows::Int, ncols::Int, bg::Char=' ')
    H, W = 2*nrows - 1, 2*ncols - 1
    return [fill(bg, W) for _ in 1:H]
end

function _rc(idx::Int, ncols::Int)
    return divrem(idx - 1, ncols) .+ (1, 1)
end

mutable struct SnakeBAR
    total::Int
    ch::Char
    bg::Char
    pad_x::Int
    pad_y::Int
    desc::String

    ham::Hamiltonian
    nrows::Int
    ncols::Int
    canvas::Vector{Vector{Char}}
    draw_seq::Vector{Tuple{Int, Int}}

    _drawn_upto::Int
    _start_time::Union{Float64, Nothing}
    _hidden::Bool
    _progress::Int

    function SnakeBAR(total::Int; ch::Char='█', bg::Char=' ', seed::Union{Int, Nothing}=nothing,
                      pad_x::Int=0, pad_y::Int=0, desc::String="")
        total = max(1, total)

        cols, lines = _terminal_size()
        W = max(10, cols - 2*pad_x)
        H = max(5, lines - 2*pad_y)

        # Choose spanning-tree size to fit interleaved canvas
        st_nrows = max(1, div(H + 1, 4))
        st_ncols = max(1, div(W + 1, 4))

        st = grid_spanning_tree(st_ncols, st_nrows; seed=seed)
        ham = hamiltonian_from_spanning_tree(st)

        nrows, ncols = ham.nrows, ham.ncols
        canvas = _build_interleaved_canvas(nrows, ncols, bg)

        # Precompute (y, x) draw order: center of first cell, then (edge, next center) pairs
        order = []
        path = ham.path
        push!(order, ("center", _rc(path[1], ncols)))

        for k in 1:(length(path) - 1)
            a, b = path[k], path[k+1]
            r0, c0 = _rc(a, ncols)
            r1, c1 = _rc(b, ncols)
            # edge between adjacent cells in interleaved canvas
            if r0 != r1
                # vertical edge: between rows
                y = 2 * min(r0, r1)
                x = 2 * c0 - 1
            else
                # horizontal edge: between columns
                y = 2 * r0 - 1
                x = 2 * min(c0, c1)
            end
            push!(order, ("edge", (y, x)))
            push!(order, ("center", (r1, c1)))
        end

        # Convert to canvas coordinates
        draw_seq = Tuple{Int, Int}[]
        for (kind, val) in order
            if kind == "center"
                r, c = val
                push!(draw_seq, (2*r - 1, 2*c - 1))  # Adjust for 1-indexing
            else
                y, x = val
                push!(draw_seq, (y, x))
            end
        end

        new(total, ch, bg, pad_x, pad_y, desc, ham, nrows, ncols, canvas, draw_seq,
            0, nothing, false, 0)
    end
end

# Terminal control constants
const _HIDE_CURSOR = "\x1b[?25l"
const _SHOW_CURSOR = "\x1b[?25h"
const _CLEAR_SCREEN = "\x1b[2J"
const _HOME = "\x1b[H"

# ANSI color codes for multi-snake
const _COLORS = [
    "\x1b[91m",  # Bright red
    "\x1b[92m",  # Bright green
    "\x1b[93m",  # Bright yellow
    "\x1b[94m",  # Bright blue
    "\x1b[95m",  # Bright magenta
    "\x1b[96m",  # Bright cyan
    "\x1b[31m",  # Red
    "\x1b[32m",  # Green
    "\x1b[33m",  # Yellow
    "\x1b[34m",  # Blue
    "\x1b[35m",  # Magenta
    "\x1b[36m",  # Cyan
]
const _RESET_COLOR = "\x1b[0m"

function start!(bar::SnakeBAR)
    print(_HIDE_CURSOR)
    flush(stdout)
    bar._hidden = true
    # Clear and position once
    print(_CLEAR_SCREEN, _HOME)
    flush(stdout)
    bar._start_time = time()
    bar._progress = 0
    _repaint(bar)
    return bar
end

function close!(bar::SnakeBAR)
    # Force final repaint to show accurate final state (bypasses rate limiting)
    _repaint(bar; force=true)

    if bar._hidden
        print(_SHOW_CURSOR)
        flush(stdout)
        bar._hidden = false
    end
end

function _format_status(bar::SnakeBAR)::String
    """Return a tqdm-like status line with desc, percent, counts, ETA and rate."""
    done = bar._progress
    total = bar.total
    frac = total > 0 ? done / total : 0.0
    pct = Int(round(frac * 100))

    # timing
    start = bar._start_time === nothing ? time() : bar._start_time
    elapsed = max(0.0, time() - start)
    rate = elapsed > 0 ? done / elapsed : 0.0
    remaining = rate > 0 ? (total - done) / rate : Inf

    function fmt_time(t::Float64)::String
        if !isfinite(t)
            return "--:--"
        end
        s = Int(round(t))
        m, s = divrem(s, 60)
        h, m = divrem(m, 60)
        if h > 0
            return @sprintf("%02d:%02d:%02d", h, m, s)
        end
        return @sprintf("%02d:%02d", m, s)
    end

    e_str = fmt_time(elapsed)
    r_str = fmt_time(remaining)
    rate_str = @sprintf("%.2f it/s", rate)
    desc = bar.desc != "" ? bar.desc : "Snaking"
    return "$desc $(lpad(pct, 3))%|$done/$total [$e_str<$r_str, $rate_str]"
end

function _render_canvas(bar::SnakeBAR)::String
    # Use IOBuffer for better performance
    io = IOBuffer()
    for (i, row) in enumerate(bar.canvas)
        for char in row
            print(io, char)
        end
        if i < length(bar.canvas)
            print(io, '\n')
        end
    end
    body = String(take!(io))
    if bar.pad_x > 0 || bar.pad_y > 0 || bar.desc != ""
        lines = split(body, "\n")
        if bar.desc != ""
            # prepend a title line above the art
            title = _format_status(bar)
            lines = [title; lines]
        end
        if bar.pad_x > 0 || bar.pad_y > 0
            side = " " ^ bar.pad_x
            lines = [fill("", bar.pad_y); [side * ln * side for ln in lines]; fill("", bar.pad_y)]
        end
        body = join(lines, "\n")
    end
    return body
end

function _repaint(bar::SnakeBAR)
    print(_HOME)
    print(_render_canvas(bar))
    flush(stdout)
end

function update!(bar::SnakeBAR, n::Int=1)
    """
    Advance progress by n (like tqdm.update). Redraws only as needed.
    """
    # clamp progress
    n = max(0, n)
    done = min(bar.total, bar._progress + n)
    bar._progress = done

    # Map progress -> how many draw_seq points to reveal
    total_pts = length(bar.draw_seq)

    # Ensure we reach the end when at 100%
    if done >= bar.total
        target_upto = total_pts
    else
        frac = done / bar.total
        target_upto = Int(ceil(frac * total_pts))
    end

    # Draw newly revealed points
    for k in (bar._drawn_upto + 1):target_upto
        y, x = bar.draw_seq[k]
        if 1 <= y <= length(bar.canvas) && 1 <= x <= length(bar.canvas[1])
            bar.canvas[y][x] = bar.ch
        end
    end

    if target_upto > bar._drawn_upto
        bar._drawn_upto = target_upto
        _repaint(bar)
    end
end

function set_description!(bar::SnakeBAR, desc::String)
    bar.desc = desc
    _repaint(bar)
end

# Convenience function for use with do-block
function snake_bar(f::Function, iterable; kwargs...)
    total = length(iterable)
    bar = SnakeBAR(total; kwargs...)
    start!(bar)
    try
        for item in iterable
            f(item)
            update!(bar, 1)
        end
    finally
        close!(bar)
    end
end

# Alternative: iterator-style usage
function snake_bar(iterable; kwargs...)
    total = length(iterable)
    bar = SnakeBAR(total; kwargs...)
    start!(bar)
    Channel() do ch
        try
            for item in iterable
                put!(ch, item)
                update!(bar, 1)
            end
        finally
            close!(bar)
        end
    end
end

# Multi-snake progress bar - multiple snakes in the same maze
mutable struct MultiSnakeBAR
    total::Int
    n_snakes::Int
    ch::Char
    colors::Vector{String}
    bg::Char
    pad_x::Int
    pad_y::Int
    desc::String

    ham::Hamiltonian
    nrows::Int
    ncols::Int
    canvas::Vector{Vector{Char}}
    canvas_colors::Vector{Vector{String}}  # Color for each cell
    canvas_snake_idx::Vector{Vector{Int}}  # Which snake drew each cell (0 = empty)
    draw_seq::Vector{Tuple{Int, Int}}  # Global drawing sequence
    segment_boundaries::Vector{Int}  # Indices where each snake's section starts
    snake_segments::Vector{Vector{Tuple{Int, Int}}}  # draw_seq divided into n segments (legacy)

    _drawn_upto::Vector{Int}  # one per snake
    _drawn_upto_global::Int  # global progress through draw_seq
    _start_time::Union{Float64, Nothing}
    _hidden::Bool
    _progress::Vector{Int}  # individual progress per snake
    _last_repaint::Float64  # timestamp of last repaint for rate limiting
    _dirty::Bool  # flag to track if canvas changed since last repaint

    function MultiSnakeBAR(total::Int, n_snakes::Int;
                           ch::Char='█',
                           colors::Union{Vector{String}, Nothing}=nothing,
                           bg::Char=' ',
                           seed::Union{Int, Nothing}=nothing,
                           pad_x::Int=0,
                           pad_y::Int=0,
                           desc::String="")
        total = max(1, total)
        n_snakes = max(1, n_snakes)

        # Default colors for different snakes
        if colors === nothing
            colors = [_COLORS[mod(i-1, length(_COLORS)) + 1] for i in 1:n_snakes]
        end

        cols, lines = _terminal_size()
        W = max(10, cols - 2*pad_x)
        H = max(5, lines - 2*pad_y)

        # Choose spanning-tree size to fit interleaved canvas
        st_nrows = max(1, div(H + 1, 4))
        st_ncols = max(1, div(W + 1, 4))

        st = grid_spanning_tree(st_ncols, st_nrows; seed=seed)
        ham = hamiltonian_from_spanning_tree(st)

        nrows, ncols = ham.nrows, ham.ncols
        canvas = _build_interleaved_canvas(nrows, ncols, bg)
        # Initialize color canvas (empty strings mean no color)
        canvas_colors = [fill("", length(canvas[1])) for _ in 1:length(canvas)]
        # Initialize snake index tracker (0 = empty, 1-n = snake index)
        canvas_snake_idx = [fill(0, length(canvas[1])) for _ in 1:length(canvas)]

        # Precompute draw order (same as single snake)
        order = []
        path = ham.path
        push!(order, ("center", _rc(path[1], ncols)))

        for k in 1:(length(path) - 1)
            a, b = path[k], path[k+1]
            r0, c0 = _rc(a, ncols)
            r1, c1 = _rc(b, ncols)
            # edge between adjacent cells in interleaved canvas
            if r0 != r1
                # vertical edge: between rows
                y = 2 * min(r0, r1)
                x = 2 * c0 - 1
            else
                # horizontal edge: between columns
                y = 2 * r0 - 1
                x = 2 * min(c0, c1)
            end
            push!(order, ("edge", (y, x)))
            push!(order, ("center", (r1, c1)))
        end

        # Convert to canvas coordinates
        draw_seq = Tuple{Int, Int}[]
        for (kind, val) in order
            if kind == "center"
                r, c = val
                push!(draw_seq, (2*r - 1, 2*c - 1))
            else
                y, x = val
                push!(draw_seq, (y, x))
            end
        end

        # Create non-overlapping segments - each snake gets its own exclusive path section
        total_pts = length(draw_seq)
        segment_size = div(total_pts, n_snakes)

        snake_segments = Vector{Tuple{Int, Int}}[]
        segment_boundaries = Int[]

        for i in 1:n_snakes
            # Non-overlapping: each snake starts where the previous one ended
            start_idx = 1 + (i - 1) * segment_size
            start_idx = max(1, min(start_idx, total_pts))

            end_idx = min(start_idx + segment_size - 1, total_pts)
            if i == n_snakes
                end_idx = total_pts  # Last snake extends to end to cover any remainder
            end

            push!(segment_boundaries, start_idx)
            push!(snake_segments, draw_seq[start_idx:end_idx])
        end
        push!(segment_boundaries, total_pts + 1)

        new(total, n_snakes, ch, colors, bg, pad_x, pad_y, desc,
            ham, nrows, ncols, canvas, canvas_colors, canvas_snake_idx, draw_seq, segment_boundaries, snake_segments,
            zeros(Int, n_snakes), 0, nothing, false, zeros(Int, n_snakes), 0.0, true)
    end
end

function start!(bar::MultiSnakeBAR)
    print(_HIDE_CURSOR)
    flush(stdout)
    bar._hidden = true
    print(_CLEAR_SCREEN, _HOME)
    flush(stdout)
    bar._start_time = time()
    bar._progress = zeros(Int, bar.n_snakes)
    _repaint(bar)
    return bar
end

function close!(bar::MultiSnakeBAR)
    # Force final repaint to show accurate final state (bypasses rate limiting)
    _repaint(bar; force=true)

    if bar._hidden
        print(_SHOW_CURSOR)
        flush(stdout)
        bar._hidden = false
    end
end

function _format_status(bar::MultiSnakeBAR, max_width::Union{Int,Nothing}=nothing)::String
    # Calculate overall progress
    done_total = sum(bar._progress)
    total_all = bar.total * bar.n_snakes
    frac = total_all > 0 ? done_total / total_all : 0.0
    pct = Int(round(frac * 100))

    start = bar._start_time === nothing ? time() : bar._start_time
    elapsed = max(0.0, time() - start)
    rate = elapsed > 0 ? done_total / elapsed : 0.0
    remaining = rate > 0 ? (total_all - done_total) / rate : Inf

    function fmt_time(t::Float64)::String
        if !isfinite(t)
            return "--:--"
        end
        s = Int(round(t))
        m, s = divrem(s, 60)
        h, m = divrem(m, 60)
        if h > 0
            return @sprintf("%02d:%02d:%02d", h, m, s)
        end
        return @sprintf("%02d:%02d", m, s)
    end

    e_str = fmt_time(elapsed)
    r_str = fmt_time(remaining)
    rate_str = @sprintf("%.2f it/s", rate)
    desc = bar.desc != "" ? bar.desc : "Multi-snaking ($(bar.n_snakes) snakes)"

    # Show individual snake progress
    snake_status = join(["S$(i):$(bar._progress[i])/$(bar.total)" for i in 1:bar.n_snakes], " ")

    status = "$desc $(lpad(pct, 3))%|$done_total/$total_all [$snake_status] [$e_str<$r_str, $rate_str]"

    # Truncate to max_width if specified to prevent wrapping
    if max_width !== nothing && length(status) > max_width
        status = status[1:max_width-3] * "..."
    end

    # Pad to consistent width to prevent jitter
    if max_width !== nothing && length(status) < max_width
        status = rpad(status, max_width)
    end

    return status
end

function _render_canvas(bar::MultiSnakeBAR)::String
    # Render canvas with colors using IOBuffer for better performance
    io = IOBuffer()
    for (row_idx, row) in enumerate(bar.canvas)
        for (col_idx, char) in enumerate(row)
            color = bar.canvas_colors[row_idx][col_idx]
            if color != ""
                print(io, color, char, _RESET_COLOR)
            else
                print(io, char)
            end
        end
        if row_idx < length(bar.canvas)
            print(io, '\n')
        end
    end
    body = String(take!(io))
    if bar.pad_x > 0 || bar.pad_y > 0 || bar.desc != ""
        lines = split(body, "\n")
        if bar.desc != "" || true  # Always show status for multi-snake
            # Get terminal width and pass to _format_status to prevent wrapping
            term_cols, _ = _terminal_size()
            max_status_width = max(40, term_cols - 2*bar.pad_x)  # Leave some margin
            title = _format_status(bar, max_status_width)
            lines = [title; lines]
        end
        if bar.pad_x > 0 || bar.pad_y > 0
            side = " " ^ bar.pad_x
            lines = [fill("", bar.pad_y); [side * ln * side for ln in lines]; fill("", bar.pad_y)]
        end
        body = join(lines, "\n")
    end
    return body
end

function _repaint(bar::MultiSnakeBAR; force::Bool=false)
    # Skip if nothing changed
    if !bar._dirty && !force
        return
    end

    # Rate limit repaints to max 60 FPS (16.67ms between frames) unless forced
    current_time = time()
    if !force && (current_time - bar._last_repaint) < 0.0167
        return
    end

    bar._last_repaint = current_time
    bar._dirty = false

    # Use HOME to reposition cursor - status line is now padded to consistent width
    # so no jitter, and no need for CLEAR_SCREEN which causes flashing
    print(_HOME)
    print(_render_canvas(bar))
    flush(stdout)
end

function update!(bar::MultiSnakeBAR, n::Int=1)
    """Update all snakes together by n steps - each draws independently"""
    # Batch update: update all snakes' canvas state first, then repaint once
    any_changes = false
    last_snake_at_100 = false

    for snake_idx in 1:bar.n_snakes
        changed = _update_snake_internal!(bar, snake_idx, n)
        any_changes = any_changes || changed

        # Check if last snake reached 100%
        if snake_idx == bar.n_snakes && bar._progress[snake_idx] >= bar.total
            last_snake_at_100 = true
        end
    end

    # Special handling for last snake at 100% - fill remaining empty cells
    if last_snake_at_100
        # Only check the last snake's segment range (where empty cells are likely to be)
        last_seg_start = bar.segment_boundaries[bar.n_snakes]
        for k in last_seg_start:length(bar.draw_seq)
            y, x = bar.draw_seq[k]
            if 1 <= y <= length(bar.canvas) && 1 <= x <= length(bar.canvas[1])
                if bar.canvas[y][x] == bar.bg
                    bar.canvas[y][x] = bar.ch
                    bar.canvas_colors[y][x] = bar.colors[bar.n_snakes]
                    bar.canvas_snake_idx[y][x] = bar.n_snakes
                    bar._dirty = true
                end
            end
        end
    end

    # Repaint once at the end if anything changed
    if any_changes || bar._dirty
        if last_snake_at_100
            _repaint(bar; force=true)  # Force final repaint
        else
            _repaint(bar)
        end
    end
end

function _update_snake_internal!(bar::MultiSnakeBAR, snake_idx::Int, n::Int)
    """Internal: Update snake canvas state without repainting. Returns true if changed."""
    n = max(0, n)
    done = min(bar.total, bar._progress[snake_idx] + n)
    bar._progress[snake_idx] = done

    # Each snake draws through its own segment
    segment = bar.snake_segments[snake_idx]
    total_pts = length(segment)

    if done >= bar.total
        target_upto = total_pts
    else
        frac = done / bar.total
        target_upto = Int(ceil(frac * total_pts))
    end

    # Draw new points in this snake's segment - don't overwrite other snakes
    if target_upto > bar._drawn_upto[snake_idx]
        for k in (bar._drawn_upto[snake_idx] + 1):target_upto
            y, x = segment[k]
            if 1 <= y <= length(bar.canvas) && 1 <= x <= length(bar.canvas[1])
                # Only draw if cell is empty
                if bar.canvas_snake_idx[y][x] == 0
                    bar.canvas[y][x] = bar.ch
                    bar.canvas_colors[y][x] = bar.colors[snake_idx]
                    bar.canvas_snake_idx[y][x] = snake_idx
                end
            end
        end

        bar._drawn_upto[snake_idx] = target_upto
        bar._dirty = true
        return true
    end

    return false
end

function update_snake!(bar::MultiSnakeBAR, snake_idx::Int, n::Int=1)
    """Update a specific snake - draws independently through its segment"""
    if snake_idx < 1 || snake_idx > bar.n_snakes
        error("Invalid snake index: $snake_idx (must be between 1 and $(bar.n_snakes))")
    end

    # Update the snake's state
    changed = _update_snake_internal!(bar, snake_idx, n)

    # Special handling for last snake at 100% - ensure it fills to the very end
    if snake_idx == bar.n_snakes && bar._progress[snake_idx] >= bar.total
        # Only check the last snake's segment range (where empty cells are likely to be)
        last_seg_start = bar.segment_boundaries[bar.n_snakes]
        for k in last_seg_start:length(bar.draw_seq)
            y, x = bar.draw_seq[k]
            if 1 <= y <= length(bar.canvas) && 1 <= x <= length(bar.canvas[1])
                if bar.canvas[y][x] == bar.bg
                    bar.canvas[y][x] = bar.ch
                    bar.canvas_colors[y][x] = bar.colors[snake_idx]
                    bar.canvas_snake_idx[y][x] = snake_idx
                    bar._dirty = true
                end
            end
        end
        if bar._dirty
            _repaint(bar; force=true)  # Force repaint to bypass rate limiting
        end
    elseif changed
        _repaint(bar)
    end
end

function set_description!(bar::MultiSnakeBAR, desc::String)
    bar.desc = desc
    bar._dirty = true
    _repaint(bar; force=true)
end

# Convenience function for multi-snake with do-block
function multi_snake_bar(f::Function, iterable, n_snakes::Int; kwargs...)
    total = length(iterable)
    bar = MultiSnakeBAR(total, n_snakes; kwargs...)
    start!(bar)
    try
        for item in iterable
            f(item)
            update!(bar, 1)
        end
    finally
        close!(bar)
    end
end

# Alternative: iterator-style usage
function multi_snake_bar(iterable, n_snakes::Int; kwargs...)
    total = length(iterable)
    bar = MultiSnakeBAR(total, n_snakes; kwargs...)
    start!(bar)
    Channel() do ch
        try
            for item in iterable
                put!(ch, item)
                update!(bar, 1)
            end
        finally
            close!(bar)
        end
    end
end

end # module
