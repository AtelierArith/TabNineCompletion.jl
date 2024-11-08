# TabnineCompletion.jl

Tabnine client for Julia REPL 

## Usage

### Download `binaries`

```sh
$ bash dl_binaries.sh
bash dl_binaries.sh
downloading 4.203.0/i686-pc-windows-gnu
Archive:  binaries/4.203.0/i686-pc-windows-gnu/TabNine.zip
  inflating: binaries/4.203.0/i686-pc-windows-gnu/TabNine-deep-cloud.exe
  inflating: binaries/4.203.0/i686-pc-windows-gnu/TabNine-deep-local.exe
  inflating: binaries/4.203.0/i686-pc-windows-gnu/TabNine-server-runner.exe
  inflating: binaries/4.203.0/i686-pc-windows-gnu/TabNine.exe
  inflating: binaries/4.203.0/i686-pc-windows-gnu/WD-TabNine.exe
downloading 4.203.0/x86_64-apple-darwin
Archive:  binaries/4.203.0/x86_64-apple-darwin/TabNine.zip
  inflating: binaries/4.203.0/x86_64-apple-darwin/TabNine
  inflating: binaries/4.203.0/x86_64-apple-darwin/TabNine-deep-cloud
  inflating: binaries/4.203.0/x86_64-apple-darwin/TabNine-deep-local
  inflating: binaries/4.203.0/x86_64-apple-darwin/TabNine-server-runner
  inflating: binaries/4.203.0/x86_64-apple-darwin/WD-TabNine
downloading 4.203.0/x86_64-pc-windows-gnu
Archive:  binaries/4.203.0/x86_64-pc-windows-gnu/TabNine.zip
  inflating: binaries/4.203.0/x86_64-pc-windows-gnu/TabNine-deep-cloud.exe
  inflating: binaries/4.203.0/x86_64-pc-windows-gnu/TabNine-deep-local.exe
  inflating: binaries/4.203.0/x86_64-pc-windows-gnu/TabNine-server-runner.exe
  inflating: binaries/4.203.0/x86_64-pc-windows-gnu/TabNine.exe
  inflating: binaries/4.203.0/x86_64-pc-windows-gnu/WD-TabNine.exe
downloading 4.203.0/x86_64-unknown-linux-musl
Archive:  binaries/4.203.0/x86_64-unknown-linux-musl/TabNine.zip
  inflating: binaries/4.203.0/x86_64-unknown-linux-musl/TabNine
  inflating: binaries/4.203.0/x86_64-unknown-linux-musl/TabNine-deep-cloud
  inflating: binaries/4.203.0/x86_64-unknown-linux-musl/TabNine-deep-local
  inflating: binaries/4.203.0/x86_64-unknown-linux-musl/TabNine-server-runner
  inflating: binaries/4.203.0/x86_64-unknown-linux-musl/WD-TabNine
downloading 4.203.0/aarch64-apple-darwin
Archive:  binaries/4.203.0/aarch64-apple-darwin/TabNine.zip
  inflating: binaries/4.203.0/aarch64-apple-darwin/TabNine
  inflating: binaries/4.203.0/aarch64-apple-darwin/TabNine-deep-cloud
  inflating: binaries/4.203.0/aarch64-apple-darwin/TabNine-deep-local
  inflating: binaries/4.203.0/aarch64-apple-darwin/TabNine-server-runner
  inflating: binaries/4.203.0/aarch64-apple-darwin/WD-TabNine
sed: first RE may not be empty
```

### Call `@inittabnine!`

```julia-repl
julia> using TabnineCompletion

julia> @inittabnine!

julia> using Bench # Press <TAB> here
```
