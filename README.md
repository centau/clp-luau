# clp-luau

A [POSIX](https://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html#Argument-Syntax)
compliant command line parser for Luau.

## API

### parser()

Using a table of commands, returns a function which parses a given string
returning the command name, options specified with their arguments and any
non-option arguments given.

- **Type**

    ```lua
    function parser(cmds: Commands): (input: string) -> (string, Map<string, unknown>, Array<unknown>)

    type Commands = Array<{
        name: string, -- name of command
        opts: Array<{
            long: string, -- long option name
            short: string?, -- short option name
            arg: boolean? -- option takes argument
        }>
    }>
    ```

- **Details**

    This function can error if an invalid input is given.

    The returned table of options will contain any options specified, using the
    option long name as the index, and its argument as the value. If the option
    does not take an argument, `true` will be the value.

    The returned table of arguments always has its arguments in the same order
    as given in the input string.

- **Example**

    ```lua
    local clp = require(path.to.clp)

    local cmds = {
        {
            name = "spawn",
            opts = {
                {
                    long = "amount",
                    short = "n",
                    arg = true
                }
            }
        }
    }

    local parse = clp.parser(cmds)

    local input = "spawn -n 10 zombie"
    local cmd, opts, args = parse(input)

    print(cmd) -- "spawn"
    print(opts) -- { amount = 10 }
    print(args) -- { "zombie" }
    ```

---
