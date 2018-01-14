package = "loveheaders"

version = "scm-0"

source = {
    url = "git://github.com/insideone/love.headers"
}

description = {
    summary = "love api headers builder",
    detailed = [[]],
    homepage = "https://github.com/insideone/love.headers",
    license = "MIT"
}

dependencies = {
    "lua ~> 5.1",
    "luafilesystem",
    "mobdebug",
    "argparse ~> 0.5"
}

build = {
    type = "builtin",
    modules = {
    },
    install = {
        bin = {"bin/loveheaders"}
    }
}
