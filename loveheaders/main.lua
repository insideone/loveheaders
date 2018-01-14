local lfs = require 'lfs'

getmetatable('').__mod = function (s, t)
    return s:gsub('%$(%w+)', t)
end

local loader = {
    appDir = lfs.currentdir(),
    apiDirName = 'api',
    headers = {},
    headersIndex = {},
    headersResolve = {},
    headersDir = './headers/$version'
}

function loader:load()
    local argp = require 'argparse'('loveheaders', 'build love headers file from love2d-community/love-api')

    argp:argument('version', 'Build headers for version')

    local args = argp:parse()

    if args.version == nil then
        error('version agrument is required')
    end

    local sourceDir = './'..self.apiDirName

    os.execute('rm -rf '..sourceDir)
    os.execute(
        'git clone https://github.com/love2d-community/love-api --depth 1 -b $version ' % {version = args.version} ..
        self.apiDirName
    )

    if not io.open(sourceDir) then
        error("Can't load version #$version" % {version = args.version})
    end

    local api = require(self.apiDirName..'.love_api')

    assert(api, 'LÖVE api not found.')
    print 'Generating LOVE snippets ...'

    local versionName = api.version
    if api.version == nil then
        versionName = args.version
    end

    loader:loadModule(api, nil, 0)

    local apiDir = self.headersDir % {version = versionName}
    if not io.open(apiDir) and not lfs.mkdir(apiDir) then
        error("Can't create directory: $dir" % {dir = apiDir})
    end

    self:saveTo(apiDir..'/love.lua')
end

function loader:addHeader(module, header)
    local moduleIdx

    if self.headersResolve[module] == nil then
        moduleIdx = #self.headers + 1
        self.headersIndex[moduleIdx] = module
        self.headersResolve[module] = moduleIdx
        self.headers[moduleIdx] = {}
    else
        moduleIdx = self.headersResolve[module]
    end

    table.insert(self.headers[moduleIdx], header)
end

function loader:loadModule(ref, parentModule)
    local moduleName = ref.name or 'love'
    if parentModule then
        moduleName = parentModule .. '.' .. moduleName
    end

    if ref.functions ~= nil then
        self:loadFunctions(moduleName, ref.functions)
    end

    if ref.modules ~= nil then
        for _, submoduleRef in ipairs(ref.modules) do
            self:loadModule(submoduleRef, moduleName)
        end
    end
end

function loader:loadFunctions(module, functions)
    for _, fn in ipairs(functions) do
        self:loadFunction(module, fn)
    end
end

function loader:loadFunction(module, fn)
    local doc = {fn.description}
    local args = {}

    if fn.variants ~= nil then
        for _, fnVariant in ipairs(fn.variants) do
            for type, list in pairs(fnVariant) do
                if type == 'description' then
                    table.insert(doc, list)
                else
                    local docName
                    if type == 'arguments' then
                        docName = 'param'
                    elseif type == 'returns' then
                        docName = 'return'
                    end

                    for _, entry in ipairs(list) do
                        local default = ''
                        if entry.default ~= nil then
                            default = ' --[[='..entry.default..']]'
                        end

                        if type == 'arguments' then
                            local argName = entry.name
                            if argName == '...' then
                                argName = '___'
                            end

                            if argName:sub(1, 1) == '"' then
                                argName = 'str_' .. argName:gsub('"', '')
                            end

                            table.insert(args, '--[['..entry.type..']] ' .. argName .. default)
                        end

                        table.insert(doc, '@' .. docName .. ' ' .. entry.type .. ' ' .. entry.name .. ' ' .. entry.description)
                    end
                end
            end
        end
    end

    self:addHeader(module, table.concat({
        '--[[',
        '$doc',
        ']]--',
        '$name = function($args) end'
    }, "\n") % {
        name = fn.name,
        module = module,
        args = table.concat(args, ', '),
        doc = '  '..table.concat(doc, "\n  ")
    })
end

function loader:saveTo(file)
    local headers = ''

    for moduleIdx, moduleHeaders in ipairs(self.headers) do
        local module = self.headersIndex[moduleIdx]
        headers = headers .. module .. " = {\n"

        local headersLen = #moduleHeaders
        for headerNum, header in ipairs(moduleHeaders) do
            headers = headers .. "\n" .. header
            if headerNum ~= headersLen then
                headers = headers .. ','
            end

            headers = headers .. "\n"
        end

        headers = headers .. "}\n"
    end

    headers = headers .. "return love\n"

    io.output(file):write(headers)
end

return setmetatable(loader, {__call = loader.load})
