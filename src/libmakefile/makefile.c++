/*
 * Copyright (C) 2015 Palmer Dabbelt
 *   <palmer@dabbelt.com>
 *
 * This file is part of pconfigure.
 * 
 * pconfigure is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * pconfigure is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with pconfigure.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "makefile.h++"
#include "self_path.h++"
#include <iostream>

makefile::makefile::makefile(bool verbose, const std::string& obj_dir)
: _verbose(verbose),
  _obj_dir(obj_dir)
{
}

void makefile::makefile::add_target(const target::ptr& target)
{
    _targets.push_back(target);
}

void makefile::makefile::write_to_file(const std::string& filename)
{
    auto file = fopen(filename.c_str(), "w");
    if (file == NULL) {
        std::cerr << "Unable to open " << filename << "\n";
        abort();
    }

    fprintf(file, "SHELL=/bin/bash\n\n");
    fprintf(file, ".PHONY: all\n");
    fprintf(file, ".PHONY: clean\n");
    fprintf(file, ".PHONY: cache-clean\n");
    fprintf(file, ".PHONY: report\n");
    fprintf(file, ".PHONY: install\n");
    fprintf(file, ".PHONY: uninstall\n");
    fprintf(file, "all:\n\n");

    auto stamp = check_stamp();
    for (const auto& target: _targets)
        target->write_to_file(file, _verbose, stamp);

    auto q = _verbose ? "" : "@";
    auto ptest = tool_command("ptest");
    auto quiet_report = _obj_dir + "/check-report-quiet";
    auto report = _obj_dir + "/check-report";
    fprintf(file, "%s:\n\t%smkdir -p %s\n\t%sdate > $@\n\n",
            stamp.c_str(), q, _obj_dir.c_str(), q);
    fprintf(file, "%s: %s\n\t%s%s --quiet --no-check-make-check > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n",
            quiet_report.c_str(), stamp.c_str(), q, ptest.c_str());
    fprintf(file, "%s: %s\n\t%s%s --no-check-make-check > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n",
            report.c_str(), stamp.c_str(), q, ptest.c_str());
    fprintf(file, "check: %s\n\n", quiet_report.c_str());
    fprintf(file, "report: %s\n\t%scat %s\n\n", report.c_str(), q, report.c_str());

    fclose(file);
}
