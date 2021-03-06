module config;

import std.file;
import std.path;
import std.process : environment;
import std.string;

import core.runtime;

import ae.sys.d.manager;
import ae.sys.paths;
import ae.utils.funopt;
import ae.utils.meta;
import ae.utils.sini;

static import std.getopt;

struct Opts
{
	Option!(string, hiddenOption) dir;
	Option!(string, "Path to the configuration file to use", "PATH") configFile;
	Switch!("Do not update D repositories from GitHub [local.offline]") offline;
	Option!(string, "How many jobs to run makefiles in [local.makeJobs]", "N") jobs;
	Option!(string[], "Additional configuration. Equivalent to digger.ini settings.", "NAME=VALUE", 'c', "config") configLines;

	Parameter!(string, "Action to perform (see list below)") action;
	Parameter!(immutable(string)[]) actionArguments;
}
immutable Opts opts;

struct ConfigFile
{
	DManager.Config.Build build;
	DManager.Config.Local local;
}
immutable ConfigFile config;

shared static this()
{
	alias fun = structFun!Opts;
	enum funOpts = FunOptConfig([std.getopt.config.stopOnFirstNonOption]);
	void usageFun(string) {}
	auto opts = funopt!(fun, funOpts, usageFun)(Runtime.args);

	if (opts.dir)
		chdir(opts.dir.value);

	enum CONFIG_FILE = "digger.ini";

	if (!opts.configFile)
	{
		auto searchDirs = [
			string.init,
			thisExePath.dirName,
			__FILE__.dirName,
			] ~ getConfigDirs() ~ [
			buildPath(environment.get("HOME", environment.get("USERPROFILE")), ".digger"), // legacy
		];
		version (Posix)
			searchDirs ~= "/etc/"; // legacy

		foreach (dir; searchDirs)
		{
			auto path = dir.buildPath(CONFIG_FILE);
			if (path.exists)
			{
				opts.configFile = path;
				break;
			}
		}
	}

	if (opts.configFile.value.exists)
	{
		config = cast(immutable)
			opts.configFile.value
			.readText()
			.splitLines()
			.parseIni!ConfigFile();
	}

	config.local.workDir = (config.local.workDir.length ? config.local.workDir.expandTilde() : getcwd()).absolutePath().buildNormalizedPath();

	if (opts.offline)
		config.local.offline = opts.offline;
	if (opts.jobs)
		config.local.makeJobs = opts.jobs;
	opts.configLines.parseIniInto(config);

	.opts = cast(immutable)opts;
}

@property string subDir(string name)() { return buildPath(config.local.workDir, name); }
