t = Template(; user=me)
temp_dir = mktempdir()
pkg_dir = joinpath(temp_dir, test_pkg)

@testset "GitHubPages" begin
    @testset "Plugin creation" begin
        p = GitHubPages()
        @test p.gitignore == ["/docs/build/", "/docs/site/"]
        @test isempty(p.assets)
        p = GitHubPages(; assets=[test_file])
        @test p.assets == [test_file]
        @test_throws ArgumentError GitHubPages(; assets=[fake_path])
    end

    @testset "Badge generation" begin
        p = GitHubPages()
        @test badges(p, me, test_pkg) ==  [
            "[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://$me.github.io/$test_pkg.jl/stable)"
            "[![Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://$me.github.io/$test_pkg.jl/latest)"
        ]
    end

    @testset "File generation" begin
        p = GitHubPages()
        @test gen_plugin(p, t, temp_dir, test_pkg) == ["docs/"]
        @test isdir(joinpath(pkg_dir, "docs"))
        @test isfile(joinpath(pkg_dir, "docs", "make.jl"))
        make = readchomp(joinpath(pkg_dir, "docs", "make.jl"))
        @test occursin("assets=[]", make)
        @test !occursin("deploydocs", make)
        @test isdir(joinpath(pkg_dir, "docs", "src"))
        @test isfile(joinpath(pkg_dir, "docs", "src", "index.md"))
        index = readchomp(joinpath(pkg_dir, "docs", "src", "index.md"))
        @test index == "# $test_pkg"
        rm(joinpath(pkg_dir, "docs"); recursive=true)
        p = GitHubPages(; assets=[test_file])
        @test gen_plugin(p, t, temp_dir, test_pkg) == ["docs/"]
        make = readchomp(joinpath(pkg_dir, "docs", "make.jl"))
        # Check the formatting of the assets list.
        @test occursin(
            strip("""
            assets=[
                    "assets/$(basename(test_file))",
                ]
            """),
            make,
        )
        @test isfile(joinpath(pkg_dir, "docs", "src", "assets", basename(test_file)))
        rm(joinpath(pkg_dir, "docs"); recursive=true)
        t.plugins[TravisCI] = TravisCI()
        @test gen_plugin(p, t, temp_dir, test_pkg) == ["docs/"]
        make = readchomp(joinpath(pkg_dir, "docs", "make.jl"))
        @test occursin("deploydocs", make)
        rm(joinpath(pkg_dir, "docs"); recursive=true)
    end

    @testset "Package generation with GitHubPages plugin" begin
        t = Template(; user=me, plugins=[GitHubPages()])
        generate(test_pkg, t)
        pkg_dir = joinpath(default_dir, test_pkg)

        # Check that the gh-pages branch exists.
        repo = LibGit2.GitRepo(pkg_dir)
        branches = map(b -> LibGit2.shortname(first(b)), LibGit2.GitBranchIter(repo))
        @test in("gh-pages", branches)

        # Check that the generated docs root is just the copied README.
        readme = read(joinpath(pkg_dir, "README.md"), String)
        index = read(joinpath(pkg_dir, "docs", "src", "index.md"), String)
        @test readme == index
        rm(pkg_dir; recursive=true)
    end
end

rm(temp_dir; recursive=true)
