# TabnineCompletion.jl

Tabnine client for Julia REPL

## Prerequisite

### Install commands

`julia`, `git`, `curl` and `unzip` command.

### Clone this repository

```sh
$ git clone https://github.com/AtelierArith/TabnineCompletion.jl.git
$ cd TabnineCompletion.jl
```

### Resolve dependencies

```sh
$ julia -e 'using Pkg; Pkg.activate("."); Pkg.build()'
```

## How to use

### Call `@inittabnine!`

```julia-repl
julia> using TabnineCompletion

julia> @inittabnine!

julia> using Bench # Press <TAB> here
```

