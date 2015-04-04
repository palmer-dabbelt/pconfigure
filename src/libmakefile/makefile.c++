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

makefile::makefile::makefile(void)
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
    fprintf(file, ".PHONY: all\nall:\n\n");
    fprintf(file, ".PHONY: clean\nclean:\n\n");
    fprintf(file, ".PHONY: check\ncheck:\n\n");

    for (const auto& target: _targets)
        target->write_to_file(file);

    fclose(file);
}
