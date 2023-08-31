local testkit = require "test/testkit"
local TEST, CASE, CHECK, FINISH = testkit.test()

local clp = require "src/clp"
local lex = clp.lex
local parse = clp.parse

local function CHECKEQ(a: {}, b: {}): boolean
    return CHECK(testkit.deq(a, b), 2)
end

TEST("Test A", function()
    local cmds = {{
        name = "commit",
        opts = {
            { long = "message", short = "m", arg = true :: any },
            { long = "all", short = "a" },
            { long = "verbose", short = "v" }
        }
    }}

    local function test_opt_type(mode: "short"|"long")
        local opt = mode == "short" and "-m" or "--message"
        local opt_name = mode == "short" and "m" or "message"

        do CASE (`{mode} opt with no args (should error)`)
            local s = "commit ".. opt

            local tokens = lex(s)
            CHECKEQ(tokens, {
                { type = "arg", text = "commit" },
                { type = "opt", text = opt_name }
            })

            CHECK(not pcall(parse, s, cmds))
        end

        do CASE (`{mode} opt with arg (-o=arg)`)
            local s = `commit {opt}=foo`

            local tokens = lex(s)
            CHECKEQ(tokens, {
                { type = "arg", text = "commit" },
                { type = "opt", text = opt_name, arg = "foo" }
            })

            local name, opts, args = parse(s, cmds)
            CHECK(name == "commit")
            CHECKEQ(opts, { message = "foo" })   
            CHECKEQ(args, {})
        end

        do CASE (`{mode} opt with arg (-o="1 2 3")`)
            local s = `commit {opt}="1 2 3"`

            local tokens = lex(s)
            CHECKEQ(tokens, {
                { type = "arg", text = "commit" },
                { type = "opt", text = opt_name, arg = "1 2 3" }
            })

            local name, opts, args = parse(s, cmds)
            CHECK(name == "commit")
            CHECKEQ(opts, { message = "1 2 3" })   
            CHECKEQ(args, {})
        end

        do CASE (`{mode} opt with arg (-o arg)`)
            local s = `commit {opt} foo`

            local tokens = lex(s)
            CHECKEQ(tokens, {
                { type = "arg", text = "commit" },
                { type = "opt", text = opt_name },
                { type = "arg", text = "foo" }
            })

            local name, opts, args = parse(s, cmds)
            CHECK(name == "commit")
            CHECKEQ(opts, { message = "foo" })  
            CHECKEQ(args, {})
        end

        do CASE (`{mode} opt with arg (-o "1 2 3")`)
            local s = `commit {opt} "1 2 3"`

            local tokens = lex(s)
            CHECKEQ(tokens, {
                { type = "arg", text = "commit" },
                { type = "opt", text = opt_name },
                { type = "arg", text = "1 2 3" }
            })

            local name, opts, args = parse(s, cmds)
            CHECK(name == "commit")
            CHECKEQ(opts, { message = "1 2 3" })  
            CHECKEQ(args, {})
        end
    end

    test_opt_type("short")
    test_opt_type("long")

    do CASE ("short opt with arg (-oarg)")
        local s = "commit -mfoo"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "m", opt_or_arg = "foo" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { message = "foo" })  
        CHECKEQ(args, {})
    end

    do CASE ("short opt with arg (-o\"1 2 3\")")
        local s = "commit -m\"1 2 3\""

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "m", opt_or_arg = "1 2 3" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { message = "1 2 3" })  
        CHECKEQ(args, {})
    end

    do CASE "multiple opts (-a -b)"
        local s = "commit -a -m foo"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a" },
            { type = "opt", text = "m" },
            { type = "arg", text = "foo" }
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, message = "foo" })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts (-ab)"
        local s = "commit -av"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a", opt_or_arg = "v" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, verbose = true, message = nil })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts and arg (-abc)"
        local s = "commit -amfoo"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a", opt_or_arg = "mfoo" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, message = "foo" })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts and arg (-ab\"1 2 3\")"
        local s = "commit -am\"1 2 3\""

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a", opt_or_arg = "m1 2 3" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, message = "1 2 3" })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts and arg (-ab=c)"
        local s = "commit -am=foo"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a", opt_or_arg = "m", arg = "foo" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, message = "foo" })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts and arg (-ab=\"1 2 3\")"
        local s = "commit -am=\"1 2 3\""

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a", opt_or_arg = "m", arg = "1 2 3" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, message = "1 2 3" })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts and arg (-ba=\"1 2 3\")"
        local s = "commit -ma=\"1 2 3\""

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "m", opt_or_arg = "a", arg = "1 2 3" },
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = nil, message = "a=1 2 3" })
        CHECKEQ(args, {})
    end

    do CASE "multiple opts and arg (-ab c)"
        local s = "commit -am foo"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "a", opt_or_arg = "m" },
            { type = "arg", text = "foo" }
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { all = true, message = "foo" })
        CHECKEQ(args, {})
    end

    do CASE "opt termination"
        local s = "commit -mfoo -- -a --verbose"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "commit" },
            { type = "opt", text = "m", opt_or_arg = "foo" },
            { type = "arg", text = "-a" },
            { type = "arg", text = "--verbose" }
        })

        local name, opts, args = parse(s, cmds)
        CHECK(name == "commit")
        CHECKEQ(opts, { message = "foo" })
        CHECKEQ(args, { "-a", "--verbose" })
    end
end)

TEST("Test B", function()
    local cmds = {{
        name = "the",
        opts = {
            { long = "alpha", short = "a", arg = false },
            { long = "beta", short = "b", arg = false },
            { long = "gamma", short = "c", arg = true },
            { long = "delta", short = "d", arg = true },
            { long = "ze-ta", short = nil :: any, arg = true }
        }
    }}

    do CASE "impractical"    
        local s = "the  quick   brown   fox -abc\"jumps over\"   the \"lazy \"dog -d1 --delta=false --ze-ta=1.5"

        local tokens = lex(s)
        CHECKEQ(tokens, {
            { type = "arg", text = "the" },
            { type = "arg", text = "quick" },
            { type = "arg", text = "brown" },
            { type = "arg", text = "fox" },
            { type = "opt", text = "a", opt_or_arg = "bcjumps over"},
            { type = "arg", text = "the" },
            { type = "arg", text = "lazy dog"},
            { type = "opt", text = "d", opt_or_arg = "1" },
            { type = "opt", text = "delta", arg = "false" },
            { type = "opt", text = "ze-ta", arg = "1.5" }
        })

        local parser = clp.parser(cmds)
        local cmd, opts, args = parser(s)
        
        CHECK(cmd == "the")
        CHECKEQ(opts, {
            alpha = true,
            beta = true,
            gamma = "jumps over",
            delta = false,
            ["ze-ta"] = 1.5
        })
        CHECKEQ(args, {
            "quick",
            "brown",
            "fox",
            "the",
            "lazy dog"
        })
    end
end)

-- TEST("Fuzz", function()
--     local function ran_char(): string
--         return string.char(math.random(1, 255))
--     end

--     local function ran_str(): string
--         local s = table.create(4)

--         for i = 2, 10 do
--             s[i - 1] = ran_char()
--             if math.random() > 0.7 then break end 
--         end

--         return table.concat(s)
--     end

--     local function ran_cmd(): { clp.Command }
--         local cmds = {}

--         for i = 1, 10 do
--             local cmd = {
--                 name = ran_str()
--             }
--         end

--         return cmds
--     end
-- end)

FINISH()

return nil
