#include "generate.h"
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifdef HAVE_TALLOC
#include <talloc.h>
#else
#include "extern/talloc.h"
#endif

#define MAX_LINE_SIZE 10240

void generate(const char *filename, struct context *c, struct makefile *mf)
{
    void *ctx;
    const char *proc_name;
    const char *target;
    const char *cmd;

    ctx = talloc_new(c);

    proc_name = talloc_asprintf(ctx, "%s/%s.proc", c->src_dir, filename);
    target = talloc_asprintf(ctx, "%s/%s", c->gen_dir, filename);

    cmd = talloc_asprintf(ctx, "mkdir -p %s", c->gen_dir);
    system(cmd);

    cmd = talloc_asprintf(ctx,
                          "if test ! -e %s; then ./%s --generate > %s; fi",
                          target, proc_name, target);
    system(cmd);

    makefile_create_target(mf, target);

    makefile_start_deps(mf);
    makefile_add_dep(mf, "%s", proc_name);

    {
        int fd;
        char *tmpname;
        FILE *file;
        char line[MAX_LINE_SIZE];

        tmpname = talloc_strdup(ctx, "/tmp/pconfigure.XXXXXX");
        fd = mkstemp(tmpname);

        cmd = talloc_asprintf(ctx, "./%s --deps > %s", proc_name, tmpname);
        system(cmd);

        file = fopen(tmpname, "r");
        while (fgets(line, MAX_LINE_SIZE, file) != NULL) {
            while (isspace(line[strlen(line) - 1]))
                line[strlen(line) - 1] = '\0';

            makefile_add_dep(mf, "%s", line);
        }

        close(fd);
        unlink(tmpname);
    }

    makefile_end_deps(mf);

    makefile_start_cmds(mf);
    makefile_nam_cmd(mf, "echo -e \"GEN\t%s\"", filename);
    makefile_add_cmd(mf, "mkdir -p %s", c->gen_dir);
    makefile_add_cmd(mf, "./%s --generate > %s", proc_name, target);
    makefile_end_cmds(mf);

    TALLOC_FREE(ctx);
}
