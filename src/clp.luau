--------------------------------------------------------------------------------
-- clp.luau
-- v0.1.0
--------------------------------------------------------------------------------

-- https://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html#Argument-Syntax

type Array<T> = { T }
type Map<T, U> = { [T]: U }

export type Command = {
    name: string,
    opts: { Option }?
}

export type Option = {
    long: string,
    short: string?,
    arg: boolean?
}

type Token = {
    type: "arg",
    text: string
} | {
    type: "opt",
    text: string,

    -- value that could be an opt or an arg depending on context
    -- `-ab` or `-ab=c` syntax (depends if opt -a takes an arg)
    opt_or_arg: string?, 

    -- contains arg if passed via `-o=1` or `-o1` or `-ab=c` syntax
    arg: string? 
}

local ASSERT = function(v, msg)
    if v then return end

    local s = 1

    while debug.info(1, "s") == debug.info(s, "s") do
        s += 1
    end

    error(msg, s)
end :: typeof(assert)

local function is_alpha(s: string): boolean
    return s == string.match(s, "%w+")
end

local function get_long_opt(s: string): Token?
    if string.sub(s, 1, 2) ~= "--" then return end
    local opt_name: string? = string.match(s, "[%w%-]+", 3) -- TODO: find better solution
    ASSERT(opt_name and not string.find(opt_name, "%-%-"), `malformed long option [{s}]`)
    local arg: string? = string.match(s, "=(.+)")
    return { type = "opt", text = opt_name, arg = arg }
end

local function get_short_opt(s: string): Token?
    if string.sub(s, 1, 1) ~= "-" or s == "-" then return end
    local opt_name = string.sub(s, 2, 2)
    ASSERT(is_alpha(opt_name), string.format("malformed short option -%s, option must be an alphanumeric character", opt_name))
    local arg: string? = string.match(s, "=(.+)") -- treat anything after first "=" as arg
    local opt_or_arg: string? = -- treat anything between first "%w" and "=" as opt_or_arg
        if arg then string.match(s, "%w(%w+)=")
        elseif #s > 2 then string.sub(s, 3, -1) -- if no "=" then just treat everthing after first "%w "as opt_or_arg
        else nil
    return { type = "opt", text = opt_name, arg = arg, opt_or_arg = opt_or_arg }
end

local function lex(s: string): Array<Token>
    local lexemes: Array<string> = table.create(3) do
        local cur_lexeme = ""
        local quoting = false
        for i = 1, #s do
            local char = string.sub(s, i, i)
            if char == "\"" then
                quoting = not quoting
            elseif char == " " and not quoting then
                if cur_lexeme ~= "" then
                    table.insert(lexemes, cur_lexeme)
                    cur_lexeme = ""
                end
            else
                cur_lexeme = cur_lexeme .. char
            end
        end

        ASSERT(not quoting, "malformed string; string was never closed")

        if cur_lexeme ~= "" then
            table.insert(lexemes, cur_lexeme)
        end
    end

    local i = 0
    local tokens = table.create(#lexemes) :: Array<Token>
    local opt_allowed = true

    for _, lexeme in next, lexemes do
        if lexeme == "--" then opt_allowed = false; continue end
        i += 1
        tokens[i] = opt_allowed and (get_long_opt(lexeme) or get_short_opt(lexeme)) or { type = "arg", text = lexeme } 
    end
    
    return tokens, lexemes
end

local function cast(s: string)
    return if tonumber(s) then tonumber(s)
        elseif s == "true" then true
        elseif s == "false" then false
        else s
end

local function find<T>(array: Array<T>, fn: (T) -> boolean): T?
    for _, v in array do
        if fn(v) then return v end
    end
    return nil
end

local function parse(s: string, cmds: Array<Command>): (string, Map<string, unknown>, Array<unknown>)
    local tokens = lex(s)

    local argn = 0
    local args: { unknown } = {}
    local opts: { [string]: unknown } = {}

    local cmd_name: string? = tokens[1] and tokens[1].type == "arg" and tokens[1].text or nil

    ASSERT(cmd_name, "no command name given"); assert(cmd_name)

    local cmd = find(cmds, function(cmd)
        return cmd.name == cmd_name
    end)

    ASSERT(cmd, `unknown command "{cmd_name}"`)

    do
        local i = 1
        while true do
            i += 1
            local token = tokens[i]
            if not token then break end

            if token.type == "opt" then
                local opt = cmd.opts and find(cmd.opts, function(opt)
                    return opt.long == token.text or opt.short == token.text
                end) or nil
                
                ASSERT(opt, `unknown option: {token.text}`)

                if opt.arg then
                    if token.opt_or_arg then
                        -- case [-ab=c] becomes [-a "b=c"] if -a takes arg
                        opts[opt.long] = cast(token.opt_or_arg .. (token.arg and ("="..token.arg) or "")) 
                    elseif token.arg then
                        opts[opt.long] = cast(token.arg)
                    elseif tokens[i + 1] then -- arg may of been given as separate token
                        local next_token = tokens[i + 1]
                        if next_token.type == "arg" then
                            i += 1
                            opts[opt.long] = cast(next_token.text)
                        elseif next_token.type == "opt" then -- no args were given; default
                            opts[opt.long] = opt.arg
                        end
                    else
                        ASSERT(false, `option [--{opt.long}] requires an argument`)
                    end
                else
                    opts[opt.long] = true
                    if token.opt_or_arg then
                        local opt_or_arg = token.opt_or_arg
                        table.insert(tokens, i + 1, { -- known to be another opt, push ahead for later
                            type = "opt",
                            text = string.sub(opt_or_arg, 1, 1),
                            arg = token.arg,
                            opt_or_arg = #opt_or_arg > 1 and string.sub(opt_or_arg, 2, -1) or nil
                        } :: Token)
                    elseif token.arg then
                        ASSERT(false, `option [--{opt.long}] does not take an argument`)
                    end
                end    
            elseif token.type == "arg" then
                argn += 1
                table.insert(args, cast(token.text))
            end
        end
    end

    return cmd_name, opts, args
end

local function create_parser(cmds: Array<Command>)
    local clone_cmds = {}

    local cmd_name_cache = {}

    -- verify there are no duplicate command or option names
    for i, cmd in cmds do
        local clone_cmd = { name = cmd.name, opts = {} }

        ASSERT(not cmd_name_cache[cmd.name], `duplicate command name "{cmd.name}"`)
        cmd_name_cache[cmd.name] = true

        local opt_long_cache = {}
        local opt_short_cache = {}

        if cmd.opts then for ii, opt in cmd.opts do
            ASSERT(not opt_long_cache[opt.long], `duplicate option name "{opt.long}"`)
            opt_long_cache[opt.long] = true

            if opt.short then
                ASSERT(not opt_short_cache[opt.long], `duplicate option name "{opt.short}"`)
                opt_short_cache[opt.short] = true
            end

            clone_cmd.opts[ii] = table.clone(opt)
        end end

        clone_cmds[i] = clone_cmd
    end

    return function(input: string): (string, Map<string, unknown>, Array<unknown>)
        return parse(input, clone_cmds)
    end
end

return {
    parser = create_parser,
    parse = parse,
    lex = lex
}
