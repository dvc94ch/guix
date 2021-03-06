/* GNU Guix --- Functional package management for GNU
   Copyright (C) 2016 Ludovic Courtès <ludo@gnu.org>

   This file is part of GNU Guix.

   GNU Guix is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or (at
   your option) any later version.

   GNU Guix is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.  */

#include <builtins.hh>
#include <util.hh>
#include <globals.hh>

#include <unistd.h>

namespace nix {

static void builtinDownload(const Derivation &drv,
			    const std::string &drvPath)
{
    /* Invoke 'guix perform-download'.  */
    Strings args;
    args.push_back("perform-download");
    args.push_back(drvPath);

    /* Close all other file descriptors. */
    closeMostFDs(set<int>());

    const char *const argv[] = { "download", drvPath.c_str(), NULL };

    /* XXX: Hack our way to use the 'download' script from 'LIBEXECDIR/guix'
       or just 'LIBEXECDIR', depending on whether we're running uninstalled or
       not.  */
    const string subdir = getenv("GUIX_UNINSTALLED") != NULL
	? "" : "/guix";

    const string program = settings.nixLibexecDir + subdir + "/download";
    execv(program.c_str(), (char *const *) argv);

    throw SysError(format("failed to run download program '%1%'") % program);
}

static const std::map<std::string, derivationBuilder> builtins =
{
    { "download", builtinDownload }
};

derivationBuilder lookupBuiltinBuilder(const std::string & name)
{
    if (name.substr(0, 8) == "builtin:")
    {
	auto realName = name.substr(8);
	auto builder = builtins.find(realName);
	return builder == builtins.end() ? NULL : builder->second;
    }
    else
	return NULL;
}

std::list<std::string> builtinBuilderNames()
{
    std::list<std::string> result;
    for(auto&& iter: builtins)
    {
	result.push_back(iter.first);
    }
    return result;
}

}
