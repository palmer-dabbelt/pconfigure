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
#include <iostream>

makefile::makefile::makefile(bool verbose)
: _verbose(verbose)
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

    for (const auto& target: _targets)
        target->write_to_file(file, _verbose);

    auto q = _verbose ? "" : "@";
    fprintf(file, "obj/check-all-done:\n\t%smkdir -p obj\n\t%sdate > $@\n\n", q, q);
    fprintf(file, "obj/check-report-quiet: obj/check-all-done\n\t%sptest --quiet --no-check-make-check > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n", q);
    fprintf(file, "obj/check-report: obj/check-all-done\n\t%sptest --no-check-make-check > $@.tmp && mv $@.tmp $@ || (cat $@.tmp; rm -f $@.tmp; exit 1)\n\n", q);
    fprintf(file, "check: obj/check-report-quiet\n\n");
    fprintf(file, "report: obj/check-report\n\t%scat obj/check-report\n\n", q);

    fclose(file);
}
